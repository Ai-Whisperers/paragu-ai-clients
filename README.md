# ParaguAI Clients Monorepo

All active ParaguAI client sites in one place. Replaces 24 separate repos.

## Structure

```
paragu-ai-clients/
├── README.md                   ← this file
├── deploy.sh                   ← builds + deploys all sites
├── clients/
│   ├── magnolia-peluqueria/   ← Asunción peluquería
│   ├── granja-cabral/         ← Huevos frescos Coronel Oviedo
│   ├── trentina-cerveza/      ← Cerveza Trentina brewery
│   ├── mantა-spa/             ← Asunción spa
│   ├── cocodrilo-fitness/     ← Fitness center
│   ├── bichos-gym/            ← Gym
│   ├── trentina-research/     ← Cerveza Trentina deep research
│   ├── portas-barber/         ← Barbería
│   ├── xxgym/                 ← XX Gym
│   ├── sarah-lubricants/      ← Sexitive catalog
│   └── maskarada/             ← Maskarada
└── shared/                     ← shared templates, scripts
    ├── base-template/
    ├── deploy-config/
    └── scripts/
```

## Client Status

| Client | Status | Last Update | Owner |
|--------|--------|-------------|-------|
| magnolia-peluqueria | 🟢 Live | 2026-05-15 | Paraguay team |
| granja-cabral | 🟢 Live | 2026-07-15 | Paraguay team |
| trentina-cerveza | 🟢 Live | 2026-05-15 | Brewery |
| mantა-spa | 🟢 Live | 2026-05-15 | Spa |
| cocodrilo-fitness | 🟢 Live | 2026-05-15 | Fitness |
| bichos-gym | 🟢 Live | 2026-05-15 | Gym |
| trentina-research | 🟡 Research | 2026-05-13 | Brewery |
| portas-barber | 🟢 Live | 2026-05-15 | Barber |
| xxgym | 🟢 Live | 2026-05-15 | Gym |
| sarah-lubricants | 🟢 Live | 2026-04-25 | Sarah |
| maskarada | 🟢 Live | 2026-07-15 | Paraguay team |

## Migration History

These 11 active clients were consolidated from:
- 24 separate repos in `Ai-Whisperers/` and `IvanWeissVanDerPol/`
- 13 repos were duplicates or archived — kept canonical, archived the rest

See `migration-log.md` for full audit trail.

## How to Deploy All

```bash
./deploy.sh all              # deploy all clients
./deploy.sh magnolia-peluqueria  # deploy single client
./deploy.sh --dry-run all    # preview changes
```

## Adding a New Client

```bash
./scripts/new-client.sh "Client Name" "category"
```

This creates `clients/<slug>/` with the base template, README, deploy config.
