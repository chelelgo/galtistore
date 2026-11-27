/* Tailwind (loaded from a CDN in index.html) reads its theme from here.
   Colours come from the variables in css/styles.css, so change colours THERE. */
const v = n => `hsl(var(--${n}) / <alpha-value>)`;
tailwind.config = {
  theme: {
    container: { center: true, padding: { DEFAULT: '1rem', md: '2rem' }, screens: { '2xl': '1320px' } },
    extend: {
      fontFamily: {
        sans: ['"DM Sans"', 'system-ui', 'sans-serif'],
        display: ['"Bricolage Grotesque"', '"DM Sans"', 'sans-serif']
      },
      colors: {
        border: v('border'), input: v('input'), ring: v('ring'),
        background: v('background'), foreground: v('foreground'), card: v('card'),
        primary: { DEFAULT: v('primary'), foreground: v('primary-foreground') },
        secondary: { DEFAULT: v('secondary') },
        muted: { DEFAULT: v('muted'), foreground: v('muted-foreground') },
        accent: { DEFAULT: v('accent'), foreground: v('accent-foreground') },
        destructive: v('destructive'),
        amber: v('amber')
      }
    }
  }
};
