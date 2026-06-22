import { listIntegrationProviders } from '../../lib/providers.js';

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

    return res.status(200).json({
      ok: true,
      providers: listIntegrationProviders(),
      rollout: {
        multiUser: 'ready_in_app',
        directOAuth: ['strava'],
        mobileBridgeRequired: ['apple-health'],
        bridgeBackendReady: ['apple-health', 'liverun-watch'],
        requiresPartnerApproval: ['garmin'],
        manualImportPlanned: ['file-import'],
        importOrStravaSync: ['nike-run-club']
      }
    });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
