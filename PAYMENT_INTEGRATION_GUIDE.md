# Payment & In-App Purchase Integration Guide

## Overview

This document describes the complete monetization system for Traitus AI, including Free vs Pro plans, in-app purchase integration, and server-side validation.

## Current Architecture

### Plans

- **Free Plan**: Full access to all features
- **Pro Plan**: Full access to all features (future premium features may be added)

### Database Schema

#### Note: Models Table Removed

The `models` table has been removed. The app now uses a single model configured via `OPENROUTER_MODEL` environment variable.

#### `user_entitlements` Table
Tracks user subscription status.

```sql
CREATE TABLE user_entitlements (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan text NOT NULL CHECK (plan IN ('free','pro')),
  status text NOT NULL DEFAULT 'active',     -- 'active' | 'expired' | 'revoked'
  source text DEFAULT 'apple',               -- 'apple' | 'google' | 'huawei' | 'stripe' | 'manual'
  original_transaction_id text,              -- Store transaction ID for reconciliation
  renews_at timestamptz,                     -- When subscription renews
  updated_at timestamptz NOT NULL DEFAULT now()
);
```

### Code Structure

#### Services

1. **`EntitlementsService`** (`lib/services/entitlements_service.dart`)
   - Fetches user's current plan from Supabase
   - Returns `UserPlan.free` or `UserPlan.pro`
   - Safe fallback to Free if DB unavailable

**Note:** Model selection has been removed. The app now uses a single model from `OPENROUTER_MODEL` environment variable.

2. **Upgrade Page** (`lib/ui/pro_upgrade_page.dart`)
   - Displays features and pricing
   - Monthly ($7.99) and Yearly ($59.99) buttons
   - Restore Purchases option
   - Currently shows placeholder (IAP not yet integrated)

3. **Settings Page** (`lib/ui/settings_page.dart`)
   - Shows current plan status
   - "Upgrade to Pro" button for Free users

## Payment Integration Steps

### 1. App Store (iOS) - StoreKit 2

#### Setup

1. **Create Products in App Store Connect**
   - Product ID: `pro_monthly` (Subscription, Auto-renewable)
   - Product ID: `pro_yearly` (Subscription, Auto-renewable)
   - Set prices in App Store Connect

2. **Add Dependencies** (`pubspec.yaml`)
   ```yaml
   dependencies:
     in_app_purchase: ^3.1.11  # Or latest version
   ```

3. **Create IAP Service** (`lib/services/iap_service.dart`)
   ```dart
   import 'package:in_app_purchase/in_app_purchase.dart';
   
   class IAPService {
     final InAppPurchase _iap = InAppPurchase.instance;
     
     Future<List<ProductDetails>> getProducts() async {
       final productIds = {'pro_monthly', 'pro_yearly'};
       final response = await _iap.queryProductDetails(productIds);
       return response.productDetails;
     }
     
     Future<bool> purchaseProduct(ProductDetails product) async {
       final purchaseParam = PurchaseParam(productDetails: product);
       return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
     }
     
     Future<void> restorePurchases() async {
       await _iap.restorePurchases();
     }
   }
   ```

4. **Server-Side Validation**

   - Create endpoint: `POST /api/iap/validate-apple-receipt`
   - Verify with Apple App Store Server API
   - Update `user_entitlements` table in Supabase

5. **App Store Server Notifications (ASN)**

   - Set up webhook: `POST /api/iap/webhook/apple`
   - Handle subscription events:
     - `INITIAL_BUY` → Set plan to 'pro', status 'active'
     - `DID_RENEW` → Update `renews_at`
     - `DID_CANCEL` → Set status to 'expired' when period ends
     - `REFUND` → Set status to 'revoked'

### 2. Google Play (Android) - Google Play Billing

#### Setup

1. **Create Products in Google Play Console**
   - Product ID: `pro_monthly` (Subscription)
   - Product ID: `pro_yearly` (Subscription)
   - Set prices

2. **Use Same IAP Service**
   - `in_app_purchase` package supports both iOS and Android

3. **Server-Side Validation**

   - Endpoint: `POST /api/iap/validate-google-receipt`
   - Verify with Google Play Developer API
   - Update `user_entitlements` table

4. **Real-Time Developer Notifications (RTDN)**

   - Set up Pub/Sub topic in Google Cloud
   - Webhook: `POST /api/iap/webhook/google`
   - Handle subscription events:
     - `SUBSCRIPTION_PURCHASED` → Set plan to 'pro'
     - `SUBSCRIPTION_RENEWED` → Update `renews_at`
     - `SUBSCRIPTION_CANCELED` → Mark for expiration
     - `SUBSCRIPTION_EXPIRED` → Set status to 'expired'

### 3. Huawei AppGallery - Huawei IAP Kit

#### Setup

1. **Create Products in AppGallery Connect**
   - Product IDs: `pro_monthly`, `pro_yearly`
   - Set prices

2. **Add Huawei IAP Plugin**
   ```yaml
   dependencies:
     huawei_iap: ^6.0.0+301  # Or latest version
   ```

3. **Server-Side Validation**

   - Endpoint: `POST /api/iap/validate-huawei-receipt`
   - Verify with Huawei IAP API
   - Update `user_entitlements` table

4. **Subscription Callbacks**

   - Webhook: `POST /api/iap/webhook/huawei`
   - Handle subscription lifecycle events

## Server-Side Implementation

### Required Endpoints

#### 1. Validate Receipt/Purchase Token

```
POST /api/iap/validate
Body: {
  "store": "apple" | "google" | "huawei",
  "productCode": "pro_monthly" | "pro_yearly",
  "transactionPayload": { ... }  // Store-specific receipt data
}

Response: {
  "success": true,
  "plan": "pro",
  "renewsAt": "2024-12-31T23:59:59Z"
}
```

**Implementation Steps:**
1. Extract transaction ID and receipt data from payload
2. Verify with store's validation API (Apple/Google/Huawei)
3. Check subscription status (active, expired, canceled)
4. Upsert `user_entitlements` in Supabase:
   ```sql
   INSERT INTO user_entitlements (user_id, plan, status, source, original_transaction_id, renews_at)
   VALUES ($1, 'pro', 'active', $2, $3, $4)
   ON CONFLICT (user_id) DO UPDATE
   SET plan = 'pro',
       status = 'active',
       source = EXCLUDED.source,
       original_transaction_id = EXCLUDED.original_transaction_id,
       renews_at = EXCLUDED.renews_at,
       updated_at = now();
   ```
5. Return success response

#### 2. Webhook Handlers

**Apple App Store Server Notifications:**
```
POST /api/iap/webhook/apple
Body: { Apple ASN v2 JSON payload }
```

**Google Play Real-Time Developer Notifications:**
```
POST /api/iap/webhook/google
Body: { Pub/Sub message with RTDN payload }
```

**Huawei Subscription Callbacks:**
```
POST /api/iap/webhook/huawei
Body: { Huawei callback payload }
```

**Implementation:**
- Parse store-specific payload
- Extract `user_id` (from transaction metadata)
- Update `user_entitlements` based on event type
- Handle edge cases (refunds, grace periods, etc.)

### Security Considerations

1. **Always validate on server** - Never trust client-side receipt data
2. **Use environment variables** for store API keys/secrets
3. **Verify transaction signatures** - Each store provides signature verification
4. **Rate limiting** - Prevent abuse of validation endpoints
5. **Idempotency** - Handle duplicate webhook deliveries safely

## Client-Side Integration

### Purchase Flow

1. User taps "Subscribe Monthly" or "Subscribe Yearly"
2. IAP service queries products from store
3. Show purchase dialog (handled by store)
4. On successful purchase:
   - Get receipt/transaction data
   - Send to server: `POST /api/iap/validate`
   - Server validates and updates Supabase
   - Refresh entitlements on client
   - Update UI to show Pro features

### Restore Purchases Flow

1. User taps "Restore Purchases"
2. IAP service calls `restorePurchases()`
3. Get all past transactions
4. Send each to server for validation
5. Server updates entitlements
6. Refresh UI

### Code Example (Future Implementation)

```dart
// lib/services/iap_service.dart (to be created)
class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final StreamController<List<PurchaseDetails>> _purchaseController = StreamController();
  
  Stream<List<PurchaseDetails>> get purchaseStream => _purchaseController.stream;
  
  Future<void> initialize() async {
    // Listen to purchase updates
    _iap.purchaseStream.listen((purchases) {
      _handlePurchases(purchases);
    });
  }
  
  Future<void> purchaseProMonthly() async {
    final products = await getProducts();
    final monthly = products.firstWhere((p) => p.id == 'pro_monthly');
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: monthly));
  }
  
  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        // Send to server for validation
        await _validateWithServer(purchase);
      }
    }
  }
  
  Future<void> _validateWithServer(PurchaseDetails purchase) async {
    // POST to your server endpoint
    final response = await http.post(
      Uri.parse('https://your-api.com/api/iap/validate'),
      body: jsonEncode({
        'store': Platform.isIOS ? 'apple' : 'google',
        'productCode': purchase.productID,
        'transactionPayload': purchase.verificationData.serverVerificationData,
      }),
    );
    
    if (response.statusCode == 200) {
      // Refresh entitlements
      await EntitlementsService().getCurrentUserPlan();
      // Update UI
    }
  }
}
```

## Testing

### Test Accounts

1. **Sandbox Accounts** (App Store/Google Play)
   - Create test accounts in store consoles
   - Use sandbox environment for testing

2. **Test Products**
   - Create test products with $0.00 price
   - Use for development/testing

### Test Scenarios

1. ✅ Purchase flow (monthly and yearly)
2. ✅ Restore purchases
3. ✅ Subscription renewal
4. ✅ Subscription cancellation
5. ✅ Refund handling
6. ✅ Expired subscription
7. ✅ Family sharing (if enabled)
8. ✅ Cross-device sync

## Monitoring & Analytics

### Key Metrics to Track

1. **Conversion Rate**: Free → Pro
2. **Churn Rate**: Pro cancellations
3. **Revenue**: Monthly recurring revenue (MRR)
4. **Average Revenue Per User (ARPU)**
5. **Lifetime Value (LTV)**

### Logging

Log all IAP events:
- Purchase attempts
- Purchase successes/failures
- Validation results
- Webhook events
- Errors

## Troubleshooting

### Common Issues

1. **Receipt validation fails**
   - Check store API credentials
   - Verify receipt format
   - Check server logs

2. **Webhook not received**
   - Verify webhook URL in store console
   - Check server logs
   - Test with manual webhook trigger

3. **Entitlement not updating**
   - Check Supabase RLS policies
   - Verify user_id matches
   - Check transaction status

4. **Cross-platform sync issues**
   - Ensure same user account across platforms
   - Check source field in database

## Next Steps

1. ✅ Database schema created
2. ✅ UI components (upgrade page, settings) created
3. ⏳ Integrate `in_app_purchase` package
5. ⏳ Create IAP service
6. ⏳ Implement server endpoints (validation + webhooks)
7. ⏳ Test with sandbox accounts
8. ⏳ Set up monitoring/analytics
9. ⏳ Submit to app stores

## References

- [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [Google Play Billing](https://developer.android.com/google/play/billing)
- [Huawei IAP](https://developer.huawei.com/consumer/en/doc/development/HMSCore-Guides/introduction-0000001050033062)
- [Flutter in_app_purchase](https://pub.dev/packages/in_app_purchase)
- [Supabase RLS](https://supabase.com/docs/guides/auth/row-level-security)

## Support

For issues or questions:
1. Check server logs for errors
2. Verify database entries in Supabase
3. Test with sandbox accounts
4. Review store-specific documentation

---

**Last Updated**: 2024
**Status**: UI Complete, IAP Integration Pending

