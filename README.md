# Galti Mini-Mart

Light-mode, phone-first shop with a back office (orders, POS, products with photo upload, delivery). Runs on Supabase + Vercel.

## What each file does (this is where to change things)

```
index.html              Page shell. Fonts, page title, which scripts load.
config.js               YOUR Supabase URL + anon key (leave your existing one if it is already filled in)
css/styles.css          Colours, fonts, buttons, inputs. Change the whole look from the :root block at the top.
js/tailwind.config.js   Tailwind theme (fonts, container width). Colours here read from styles.css.
js/catalog.js           The 6,159 starter products (data only, rarely edited by hand)
js/app.js               The whole shop and back office (React components)
images/hero-1..3.jpg    Home page photos. Replace a file with the SAME NAME to change the photo.
supabase/schema.sql     Database + security rules + photo storage (run once in Supabase)
supabase/products_seed.csv / .sql   Starter products for the database
data/                   Script that rebuilds catalog.json from the Excel file
```

## Quick changes

| I want to change… | File | Look for |
|---|---|---|
| Brand colours (green, tomato, cream) | css/styles.css | `--primary`, `--accent`, `--background` at the top |
| Headline, hero text and buttons | js/app.js | `function Hero` |
| Hero photos | images/ | replace hero-1.jpg, hero-2.jpg, hero-3.jpg |
| The four icons under the hero | js/app.js | `const Trust` |
| "How ordering works" text | js/app.js | `const Steps` |
| Department tile colours | js/app.js | `const TINT` |
| Home page row titles | js/app.js | `function Home` |
| Footer text and links | js/app.js | `function Footer` |
| Logo (the leaf) | js/app.js | `const Leaf` (replace the SVG with `<img src="images/logo.png" ...>`) |
| Fonts | index.html + css/styles.css | the Google Fonts `<link>` and `font-family` lines |
| WhatsApp number, zones, fees, riders, free-delivery amount | Back office → Delivery tab | saved in the database, no code needed |
| Products, prices, stock, photos | Back office → Products tab | no code needed |
| Promo code (GALTI10) | Supabase → Table Editor → promos | |

**Tip:** on GitHub, open the repo and press the `.` key. It opens a full editor in your browser (github.dev) where Ctrl+F searches every file, so you can type `function Hero` and jump straight to it. Commit from there, and Vercel redeploys automatically.

## Putting it on GitHub (replacing the old single-file version)
1. Unzip this folder.
2. In your GitHub repo click **Add file → Upload files** and drag in EVERYTHING inside the folder (the folders `css`, `js`, `images`, `supabase`, `data` and the files `index.html`, `vercel.json`, `.gitignore`, `README.md`). This replaces the old `index.html`.
3. **config.js:** if your repo already has a `config.js` with your Supabase keys, do NOT upload this one over it. Otherwise paste your keys into the one in this folder first.
4. Commit. Vercel rebuilds in about a minute.

## First-time Supabase setup (skip if already done)
1. supabase.com → New project (region near Kenya). Wait until it is ready.
2. SQL Editor → paste `supabase/schema.sql` → Run.
3. Table Editor → products → Insert → Import data from CSV → `supabase/products_seed.csv` (or run `products_seed.sql`). You should see 6,159 rows.
4. Authentication → Users → Add user (your email + password, tick Auto Confirm). Then SQL Editor: `insert into public.admins (email) values ('you@example.com');`
5. Project Settings → API → copy the Project URL and the anon public key into `config.js`.
6. Open `your-site.vercel.app/#admin` (or the "Staff login" link in the footer) and sign in.

## Product photos
Back office → Products → Edit (or + Add product). Tap **Take photo** (phone camera) or **Upload photo**. Photos are shrunk automatically and appear on the shop as soon as you save.

## Before real money
- M-Pesa at checkout is simulated. Real payments need Safaricom Daraja (STK Push) and a small server function. Until then treat M-Pesa orders as pay on delivery.
- Add rate limiting or a CAPTCHA in Supabase if you get spam orders.
