import { buildBridgeContract } from '../../lib/bridge-contract.js';
import { getPublicOrigin } from '../../lib/session.js';

export default async function handler(req, res) {
  try {
    if (req.method !== 'GET') return res.status(405).json({ error: 'method not allowed' });

    return res.status(200).json(buildBridgeContract(getPublicOrigin(req)));
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
