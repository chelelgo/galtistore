# Galti Mini-Mart

Hyperlocal grocery storefront for Elgonview, Eldoret. Single-file React + Tailwind site in the Lace design system (black / white / electric green).

## Run locally
Open `index.html` in a browser. No build step needed.

## Features
Search with Swahili synonyms, shop filters, product pages, basket with free-delivery bar and promo code (GALTI10), checkout with M-Pesa / card / cash options, order tracker, order history, wishlist.

## Before going live, edit these placeholders in `index.html`
- WhatsApp number `254700000000` (search for it, appears several times)
- Footer phone and email
- Delivery areas (`AREAS`), free-delivery threshold (`FREE`) and fee (`FEE`)
- Products (`P` array) and photos (`IMG`)

## Notes
- M-Pesa is simulated. Real payments need Safaricom Daraja and a server.
- The live order database only works inside Claude. On Vercel, checkout confirms the order and offers a WhatsApp message to the shop.

## Other versions
`versions/` holds two earlier design variations for reference.
