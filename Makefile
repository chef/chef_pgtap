EXTENSION = chef_pgtap
DATA = sql/*.sql
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
