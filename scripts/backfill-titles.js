const admin = require('firebase-admin');
const app = admin.initializeApp({ projectId: 'wickett-13423' });
const db = admin.firestore();

const JUPITER_API = 'https://prediction-market-api.jup.ag/api/v1';

async function backfill() {
  console.log('Fetching bets without titles...');

  const bets = await db.collection('prediction_bets').limit(100).get();
  const needsTitle = bets.docs.filter(d => {
    const data = d.data();
    return !data.marketTitle || data.marketTitle === 'Unknown';
  });

  console.log('Found ' + needsTitle.length + ' bets without titles');

  // Group by wallet
  const byWallet = {};
  for (const doc of needsTitle) {
    const wallet = doc.data().walletAddress;
    if (!byWallet[wallet]) byWallet[wallet] = [];
    byWallet[wallet].push({ id: doc.id, data: doc.data() });
  }

  let updated = 0;

  for (const [wallet, walletBets] of Object.entries(byWallet)) {
    console.log('Processing wallet ' + wallet.slice(0,8) + '... (' + walletBets.length + ' bets)');

    // Fetch positions
    const res = await fetch(JUPITER_API + '/positions?ownerPubkey=' + wallet + '&limit=50');
    if (!res.ok) {
      console.log('  Failed to fetch positions');
      continue;
    }

    const data = await res.json();
    const positions = data.data || [];

    if (positions.length === 0) {
      console.log('  No positions found');
      continue;
    }

    // Get market title from first position
    const pos = positions[0];
    if (!pos.eventMetadata || !pos.eventMetadata.title) {
      console.log('  No event metadata');
      continue;
    }

    const title = pos.marketMetadata && pos.marketMetadata.title
      ? pos.eventMetadata.title + ' - ' + pos.marketMetadata.title
      : pos.eventMetadata.title;

    // Update all bets for this wallet
    for (const bet of walletBets) {
      await db.collection('prediction_bets').doc(bet.id).update({
        marketTitle: title,
        marketCategory: pos.eventMetadata.category || 'Unknown'
      });
      updated++;
    }

    console.log('  Updated ' + walletBets.length + ' bets with: ' + title);

    await new Promise(r => setTimeout(r, 200));
  }

  console.log('Done! Updated ' + updated + ' bets');
  process.exit(0);
}

backfill().catch(e => { console.error(e); process.exit(1); });
