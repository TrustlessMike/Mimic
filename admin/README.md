# Mimic Admin Dashboard

Internal admin dashboard for monitoring Mimic platform activity.

## Tech Stack

- **Framework**: React 18 + TypeScript
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **Data**: Firebase Firestore
- **Auth**: Firebase Admin Auth

## Features

- User management and analytics
- Transaction monitoring
- Coinbase transfer tracking
- Auto-swap logs
- Platform insights

## Development

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Environment

Create `.env.local` with your Firebase config:

```env
VITE_FIREBASE_API_KEY=your-api-key
VITE_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=your-project-id
```

## Structure

```
admin/
├── src/
│   ├── components/     # Reusable UI components
│   │   ├── common/     # Buttons, inputs, badges
│   │   ├── dashboard/  # Dashboard-specific components
│   │   └── layout/     # App shell, sidebar, header
│   ├── hooks/          # Custom React hooks
│   ├── pages/          # Route pages
│   ├── services/       # Firebase client
│   └── types/          # TypeScript types
├── index.html          # Entry HTML
├── tailwind.config.js  # Tailwind configuration
└── vite.config.ts      # Vite configuration
```
