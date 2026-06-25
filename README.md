# Jacksonville Jaguars Franchise Records

Option B architecture: R ETL builds Parquet fact tables, and a static Vite site queries them in the browser with DuckDB WASM.

## Project structure

```
config/          Stat registry (YAML) and site metadata
R/               ETL scripts
data/raw/pfr/    Manual 1995-1998 PFR passing CSVs
data/processed/  Generated Parquet + JSON (gitignored locally)
web/             Static frontend
```

## Local setup

### R ETL

```bash
cd jags-records
Rscript -e 'install.packages(c("nflreadr","dplyr","arrow","lubridate","jsonlite","yaml","cli","glue","tibble"))'
Rscript R/run_etl.R
```

Set `JAGS_USE_NFLREADR=TRUE` to prefer the nflreadr loaders (used in CI). By default the pipeline downloads nflverse Parquet releases directly.

Output files:

- `data/processed/player_game_stats.parquet`
- `data/processed/manifest.json`
- `data/processed/stats.json`
- copies to `web/public/data/`

### Frontend

```bash
cd web
npm install
npm run dev
```

Open http://localhost:5173

## Adding positions later

1. Add a position group block to `config/stats.yaml`
2. Add stat columns to `FACT_COLUMNS` in `R/03_build_player_game.R`
3. Generalize ingest to loop over YAML position groups
4. Enable the position picker in the frontend

## Deployment

- **GitHub Pages:** enabled via `.github/workflows/deploy.yml`
- **Cloudflare Pages:** build command `npm run build`, output directory `web/dist`

Weekly data refresh runs via `.github/workflows/etl.yml` (Tuesdays 12:00 UTC).

## Data sources

- [nflverse/nflreadr](https://nflreadr.nflverse.com/) (1999+, CC-BY 4.0)
- [Pro-Football-Reference](https://www.pro-football-reference.com/teams/jax/) (1995–1998 season supplement)

## Notes

- Historical Jaguars games may appear as `JAC` or `JAX`; both are normalized to `JAX`.
- Weekly nflverse stats are joined to schedules by season/week/opponent to derive game dates for age filters.
- 1995–1998 legacy rows use season-level PFR totals with a September 1 proxy date for age filtering.
