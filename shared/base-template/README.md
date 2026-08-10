# Base Template for ParaguAI Client Sites

Copy this template to create a new client site.

```
cp -r shared/base-template clients/<client-slug>
```

## What's Included

- `index.html` — Base HTML with header/footer
- `index-en.html` — English version (optional)
- `style.css` — Base styles (warm cream + terracotta palette)
- `DEPLOY.md` — Deploy instructions
- `client.json` — Client metadata

## Customization Checklist

- [ ] Replace `{{CLIENT_NAME}}` in all files
- [ ] Replace `{{WHATSAPP}}` with client's WhatsApp number
- [ ] Replace `{{ADDRESS}}` with client's physical address
- [ ] Replace `{{EMAIL}}` with client's email
- [ ] Update services/pricing in `content/services.json`
- [ ] Add client logo to `assets/logo.svg`
- [ ] Test on mobile (use browser dev tools)
- [ ] Verify Cloudflare Pages auto-deploys
- [ ] Run `./scripts/validate-client.sh .`

## Deploy

Each client has its own `deploy.sh` wrapper that calls the global ParaguAI deploy system:

```bash
hermes-deploy-cf <client-slug> .
```

Set `CLOUDFLARE_API_TOKEN` env var or run `wrangler login` first.

## Style Guide

- **Colors**:
  - `--warm-cream: #FDF8F0` (background)
  - `--terracotta: #C4956A` (CTA buttons)
  - `--text: #3D2E1F` (body)
- **Fonts**: System UI stack (-apple-system, BlinkMacSystemFont, Segoe UI)
- **Layout**: Single-column, max-width 1100px
- **Mobile-first**: 768px breakpoint

## When to Use This Template

✓ Local business (single service or category)
✓ Spanish + English
✓ Simple contact form / WhatsApp CTA
✓ Paraguay pricing in Guaraníes (Gs)

## When NOT to Use This

✗ Multi-page SaaS (use Next.js platform instead)
✗ E-commerce (use shop-platform)
✗ Blog-heavy content (use content-platform)
