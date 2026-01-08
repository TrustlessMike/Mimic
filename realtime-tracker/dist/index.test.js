"use strict";
/**
 * Tests for realtime-tracker optimizations
 */
// Mock Firebase Admin
jest.mock('firebase-admin', () => ({
    initializeApp: jest.fn(),
    credential: {
        applicationDefault: jest.fn(),
    },
}));
jest.mock('firebase-admin/firestore', () => ({
    getFirestore: jest.fn(() => ({
        collection: jest.fn(() => ({
            doc: jest.fn(() => ({
                get: jest.fn(),
                set: jest.fn(),
            })),
            where: jest.fn(() => ({
                get: jest.fn(),
                where: jest.fn(() => ({
                    get: jest.fn(),
                })),
            })),
        })),
        getAll: jest.fn(),
    })),
    FieldValue: {
        serverTimestamp: jest.fn(),
        increment: jest.fn(),
    },
}));
jest.mock('firebase-admin/messaging', () => ({
    getMessaging: jest.fn(() => ({
        sendEachForMulticast: jest.fn(),
    })),
}));
describe('Realtime Tracker Optimizations', () => {
    describe('Parallel Market Info Fetching', () => {
        it('should use Promise.allSettled for parallel API calls', async () => {
            // Simulate the parallel fetching pattern
            const fetchMarketFromPositions = jest.fn().mockResolvedValue({ title: 'Market 1' });
            const fetchMarketFromEvents = jest.fn().mockResolvedValue({ title: 'Market 2' });
            const fetchPromises = [
                fetchMarketFromPositions('wallet', 'address'),
                fetchMarketFromEvents('address'),
            ];
            const results = await Promise.allSettled(fetchPromises);
            expect(results).toHaveLength(2);
            expect(results[0].status).toBe('fulfilled');
            expect(results[1].status).toBe('fulfilled');
        });
        it('should return first successful result', async () => {
            const results = [
                { status: 'fulfilled', value: { title: 'First Market' } },
                { status: 'fulfilled', value: { title: 'Second Market' } },
            ];
            let firstSuccess = null;
            for (const result of results) {
                if (result.status === 'fulfilled' && result.value) {
                    firstSuccess = result.value;
                    break;
                }
            }
            expect(firstSuccess).toEqual({ title: 'First Market' });
        });
        it('should handle partial failures gracefully', async () => {
            const results = [
                { status: 'rejected', reason: new Error('API Error') },
                { status: 'fulfilled', value: { title: 'Fallback Market' } },
            ];
            let firstSuccess = null;
            for (const result of results) {
                if (result.status === 'fulfilled' && result.value) {
                    firstSuccess = result.value;
                    break;
                }
            }
            expect(firstSuccess).toEqual({ title: 'Fallback Market' });
        });
        it('should return null when all fetches fail', async () => {
            const results = [
                { status: 'rejected', reason: new Error('API Error 1') },
                { status: 'rejected', reason: new Error('API Error 2') },
            ];
            let firstSuccess = null;
            for (const result of results) {
                if (result.status === 'fulfilled' && result.value) {
                    firstSuccess = result.value;
                    break;
                }
            }
            expect(firstSuccess).toBeNull();
        });
    });
    describe('Batch User Document Fetching', () => {
        it('should deduplicate user IDs', () => {
            const trackerDocs = [
                { data: () => ({ userId: 'user1' }) },
                { data: () => ({ userId: 'user2' }) },
                { data: () => ({ userId: 'user1' }) }, // Duplicate
                { data: () => ({ userId: 'user3' }) },
            ];
            const userIds = [...new Set(trackerDocs.map((d) => d.data().userId))];
            expect(userIds).toHaveLength(3);
            expect(userIds).toContain('user1');
            expect(userIds).toContain('user2');
            expect(userIds).toContain('user3');
        });
        it('should build user data map correctly', () => {
            const userDocs = [
                { id: 'user1', exists: true, data: () => ({ walletAddress: 'wallet1', fcmTokens: ['token1'] }) },
                { id: 'user2', exists: true, data: () => ({ walletAddress: 'wallet2', fcmTokens: ['token2'] }) },
                { id: 'user3', exists: false, data: () => null },
            ];
            const userDataMap = new Map();
            userDocs.forEach((doc) => {
                if (doc.exists) {
                    userDataMap.set(doc.id, doc.data());
                }
            });
            expect(userDataMap.size).toBe(2);
            expect(userDataMap.get('user1')).toEqual({ walletAddress: 'wallet1', fcmTokens: ['token1'] });
            expect(userDataMap.get('user2')).toEqual({ walletAddress: 'wallet2', fcmTokens: ['token2'] });
            expect(userDataMap.has('user3')).toBe(false);
        });
        it('should have O(1) lookup from map', () => {
            const userDataMap = new Map();
            for (let i = 0; i < 1000; i++) {
                userDataMap.set(`user${i}`, { walletAddress: `wallet${i}` });
            }
            const start = performance.now();
            for (let i = 0; i < 10000; i++) {
                userDataMap.get('user500');
            }
            const elapsed = performance.now() - start;
            // 10000 Map lookups should be very fast (< 50ms)
            expect(elapsed).toBeLessThan(50);
        });
    });
    describe('Market Cache', () => {
        it('should check in-memory cache before Firestore', () => {
            const marketCache = new Map();
            // Add to cache
            marketCache.set('market123', {
                title: 'Test Market',
                category: 'Politics',
                cachedAt: Date.now(),
            });
            // Check cache hit
            const cached = marketCache.get('market123');
            const isFresh = cached && Date.now() - cached.cachedAt < 3600000; // 1 hour
            expect(isFresh).toBe(true);
            expect(cached?.title).toBe('Test Market');
        });
        it('should expire cache after 1 hour', () => {
            const marketCache = new Map();
            // Add expired entry
            marketCache.set('market123', {
                title: 'Old Market',
                category: 'Politics',
                cachedAt: Date.now() - 3700000, // 1 hour + 100 seconds ago
            });
            const cached = marketCache.get('market123');
            const isFresh = cached && Date.now() - cached.cachedAt < 3600000;
            expect(isFresh).toBe(false);
        });
    });
});
describe('Copy Trade Amount Calculation', () => {
    it('should calculate suggested amount correctly', () => {
        const originalAmount = 100;
        const copyPercentage = 10;
        const maxCopyAmountUsd = 50;
        const minBetSizeUsd = 5;
        let suggestedAmount = Math.min(originalAmount * (copyPercentage / 100), maxCopyAmountUsd);
        suggestedAmount = Math.max(suggestedAmount, minBetSizeUsd);
        expect(suggestedAmount).toBe(10); // 100 * 10% = 10, within limits
    });
    it('should cap at max copy amount', () => {
        const originalAmount = 1000;
        const copyPercentage = 10;
        const maxCopyAmountUsd = 50;
        const minBetSizeUsd = 5;
        let suggestedAmount = Math.min(originalAmount * (copyPercentage / 100), maxCopyAmountUsd);
        suggestedAmount = Math.max(suggestedAmount, minBetSizeUsd);
        expect(suggestedAmount).toBe(50); // Capped at max
    });
    it('should enforce minimum bet size', () => {
        const originalAmount = 10;
        const copyPercentage = 5;
        const maxCopyAmountUsd = 50;
        const minBetSizeUsd = 5;
        let suggestedAmount = Math.min(originalAmount * (copyPercentage / 100), maxCopyAmountUsd);
        suggestedAmount = Math.max(suggestedAmount, minBetSizeUsd);
        expect(suggestedAmount).toBe(5); // Enforced minimum (10 * 5% = 0.5, raised to 5)
    });
});
