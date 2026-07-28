-- ---------------------------------------------------------------------------
-- Planner cost hints for the RDKit cartridge
--
-- Run this ONCE against each database after `CREATE EXTENSION rdkit`, e.g.
--
--     docker exec -i <container> psql -U protwis -d protwis \
--       -f /usr/local/share/postgresql/rdkit-tuning.sql
--
-- Safe to run repeatedly. Safe to run before the extension exists (it becomes a
-- no-op). It changes no data and no query results -- only the planner's cost
-- estimates, and therefore its willingness to parallelise.
--
-- WHY THIS IS NEEDED
--
-- The RDKit cartridge declares its molecule-parsing functions PARALLEL SAFE and
-- IMMUTABLE but gives most of them no COST clause, so PostgreSQL prices them at
-- the default of 1 (0.0025 cost units) -- the same as an integer comparison.
-- Measured on this image, `mol_from_smiles(cstring)` costs about 123 microseconds
-- per call, so the planner's estimate is off by roughly five orders of magnitude.
--
-- The consequence is that a bulk molecule build plans as a serial sequential scan
-- even on a many-core machine, because the planner sees nothing expensive enough
-- to justify starting workers. Measured on 222,036 real ligands, 12 cores:
--
--   as shipped (COST 1)                            55.5 s   0 workers
--   with COST 1000                                 14.1 s   3 workers
--   + ALTER TABLE ... SET (parallel_workers = 8)    6.9 s   8 workers
--
-- Note that the cartridge already declares COST 100 on the `text` overload of
-- `mol_from_smiles` but not on the `cstring` overload, which is the one the
-- generated SQL actually calls -- so the omission looks like an oversight rather
-- than a deliberate choice.
--
-- The second step (worker count) is capped by table size, not by function cost:
-- PostgreSQL derives the worker count from how large the relation is, and a table
-- of a few tens of megabytes qualifies for only a handful of workers no matter how
-- expensive the per-row work is. Setting `parallel_workers` on the relation itself
-- overrides that heuristic without touching global settings -- which is why this
-- file does that rather than lowering `min_parallel_table_scan_size` globally.
-- ---------------------------------------------------------------------------

\set ON_ERROR_STOP on

DO $$
DECLARE
    fn text;
    parse_fns text[] := ARRAY[
        'mol_from_smiles(cstring)',
        'qmol_from_smiles(cstring)',
        'mol_from_ctab(cstring,boolean,boolean,boolean)',
        'qmol_from_ctab(cstring,boolean,boolean)',
        'mol_from_json(cstring)'
    ];
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'rdkit') THEN
        RAISE NOTICE 'rdkit extension not present in this database; nothing to do.';
        RETURN;
    END IF;

    -- Molecule/query parsing. Only mol_from_smiles(cstring) was benchmarked
    -- directly; the others are the same class of work (text -> molecular graph,
    -- including sanitisation) and are costed consistently with it.
    FOREACH fn IN ARRAY parse_fns LOOP
        IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = to_regprocedure(fn)) THEN
            EXECUTE format('ALTER FUNCTION %s COST 1000', fn);
            RAISE NOTICE 'COST 1000 -> %', fn;
        END IF;
    END LOOP;
END
$$;

-- ---------------------------------------------------------------------------
-- Relation-level worker counts.
--
-- Applied only to tables that exist, so this section is a no-op outside a GPCRdb
-- schema. The two chemistry tables are small in bytes but very expensive per row,
-- which is exactly the case PostgreSQL's table-size heuristic gets wrong.
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    t text;
    tables text[] := ARRAY['ligand', 'ligand_ligandmol', 'ligand_ligandfingerprint'];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                   WHERE c.relname = t AND c.relkind = 'r' AND n.nspname = 'public') THEN
            EXECUTE format('ALTER TABLE public.%I SET (parallel_workers = 8)', t);
            RAISE NOTICE 'parallel_workers = 8 -> %', t;
        END IF;
    END LOOP;
END
$$;

-- Verify what was applied:
--
--   SELECT p.oid::regprocedure AS function, p.procost
--   FROM pg_proc p JOIN pg_depend d ON d.objid = p.oid
--   JOIN pg_extension e ON e.oid = d.refobjid AND e.extname = 'rdkit'
--   WHERE p.procost > 1 ORDER BY p.procost DESC, 1;
--
--   SELECT relname, reloptions FROM pg_class WHERE reloptions IS NOT NULL;
