export default function Home() {
  return (
    <main style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>Mimic API</h1>
      <p>Prediction market tracking API</p>
      <h2>Endpoints</h2>
      <ul>
        <li><a href="/api/health">/api/health</a> - Health check</li>
        <li><a href="/api/stats">/api/stats</a> - Overall stats</li>
        <li><a href="/api/wallets">/api/wallets</a> - Smart money wallets</li>
        <li><a href="/api/bets">/api/bets</a> - Recent prediction bets</li>
        <li><a href="/api/markets">/api/markets</a> - Jupiter markets</li>
        <li><a href="/api/polymarket">/api/polymarket</a> - Polymarket matches</li>
      </ul>
    </main>
  );
}
