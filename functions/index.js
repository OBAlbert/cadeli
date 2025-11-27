    const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
    const { setGlobalOptions } = require('firebase-functions/v2');
    const admin = require('firebase-admin');
    const axios = require('axios');
    const { defineSecret } = require('firebase-functions/params');
    const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
    const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');
    const SCHEDULER_KEY_SECRET = defineSecret('SCHEDULER_KEY'); // optional: replaces env fallback
    const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');


    admin.initializeApp();
    setGlobalOptions({ region: 'us-central1' });

    const WOO_BASE = 'https://lightsalmon-okapi-161109.hostingersite.com';
    const WOO_KEY = 'ck_d27a39b0086e946fbb734f7d61af026b11cfcb25';
    const WOO_SECRET = 'cs_92b4661b7f110883e3c2869a50b909d01114cea3';

    const wooAxios = axios.create({
      baseURL: `${WOO_BASE}/wp-json/wc/v3/`,
      auth: { username: WOO_KEY, password: WOO_SECRET },
    });

    function logAuth(label, req, extra = {}) {
      console.log(`[${label}]`, {
        uid: req.auth?.uid || null,
        tokenEmail: req.auth?.token?.email || null,
        hasAuthHeader: Boolean(req.rawRequest?.headers?.authorization),
        project: process.env.GCLOUD_PROJECT,
        region: 'us-central1',
        ...extra,
      });
    }

    async function checkAdmin(req) {
      if (!req.auth) throw new HttpsError('unauthenticated', 'User not logged in');
      const uid = req.auth.uid;
      const doc = await admin.firestore().collection('users').doc(uid).get();
      if (!doc.exists || !doc.data().isAdmin) {
        throw new HttpsError('permission-denied', 'Not authorized');
      }
    }

    async function computeCartTotalCentsEUR(cartItems) {
      // Look up Woo product prices to avoid trusting the client
      let total = 0;
      for (const it of (cartItems || [])) {
        const id = Number(it.id);
        const qty = Number(it.quantity || 1);
        if (!id || qty <= 0) continue;
        const { data: p } = await wooAxios.get(`products/${id}`);
        const price = parseFloat(p.price || p.regular_price || '0');
        total += price * qty;
      }
      return Math.round(total * 100); // cents
    }

    async function ensureChatAndSystemMessage(orderDocId, customerId, text, status = 'pending') {
  const db = admin.firestore();
  const chatRef = db.collection('chats').doc(orderDocId);

  // 1) Read real admin UIDs from /config/admins
  let adminUids = [];
  try {
    const cfg = await db.collection('config').doc('admins').get();
    adminUids = Array.isArray(cfg.data()?.uids) ? cfg.data().uids.map(String) : [];
  } catch (_) { adminUids = []; }

  // 2) Resolve customer email (best effort)
  let email = null;
  try {
    const userDoc = await db.collection('users').doc(customerId).get();
    email = (userDoc.exists && userDoc.data().email) ? userDoc.data().email : null;
    if (!email) { const u = await admin.auth().getUser(customerId); email = u.email || null; }
  } catch (_) {}

  // 3) Build correct participants (customer + ALL admins)
  const participants = Array.from(new Set([customerId, ...adminUids])).filter(Boolean);

  // 4) Ensure chat shell (merge)
  const now = admin.firestore.FieldValue.serverTimestamp();
  await chatRef.set({
    orderId: orderDocId,
    customerId,
    // Keep an arbitrary adminId if you want, but NOT the literal "ADMIN"
    ...(adminUids.length ? { adminId: adminUids[0] } : {}),
    participants,                 // <-- IMPORTANT: real UIDs here
    customerEmail: email || '',
    status,
    updatedAt: now,
  }, { merge: true });

  // 5) Post a system message
  await chatRef.collection('messages').add({
    senderId: 'admin-system',
    senderRole: 'system',
    type: 'system',
    text,
    createdAt: now,
  });

  // 6) Update thread metadata
  await chatRef.set({
    lastMessage: text,
    lastSenderId: 'admin-system',
    updatedAt: now,
  }, { merge: true });
}

    async function pushToUser(uid, title, body, data = {}) {
      if (!uid || uid === 'ADMIN') return; // you can later wire real admin users
      const u = await admin.firestore().collection('users').doc(uid).get();
      const map = (u.data() || {}).fcmTokens || {};
      const tokens = Object.keys(map).filter(Boolean);
      if (!tokens.length) return;

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: Object.fromEntries(Object.entries(data).map(([k,v]) => [k, String(v)])),
      });
    }

    exports.createWooOrderFromCart = onCall(async (req) => {
  if (!req.auth) {
    throw new HttpsError('unauthenticated', 'Not logged in');
  }

  try {
    const userId = req.auth.uid;
    const { cartItems = [], address = {}, meta = {} } = req.data || {};

    if (!Array.isArray(cartItems) || cartItems.length === 0) {
      throw new HttpsError('invalid-argument', 'Cart is empty');
    }

    // ---- ENFORCE SUBSCRIPTION METADATA ----
    const timestamp = Date.now();
    meta.delivery_type = 'subscription';
    meta.order_placed_at_ms = timestamp;
    meta.frequency = meta.frequency || 'Weekly';

    // ---- Build Woo line items ----
    const lineItems = cartItems.map((it) => ({
      product_id: Number(it.id),
      quantity: Number(it.quantity || 1),
    }));

    // ---- Woo meta_data (compact, consistent naming) ----
    const meta_data = [
      { key: 'firebase_uid', value: userId },
      { key: 'cadeli_order_doc_id', value: 'PENDING_SET' },

      { key: 'delivery_type', value: 'subscription' },
      { key: 'frequency', value: meta.frequency },

      { key: 'customer_name', value: meta.customer_name || '' },
      { key: 'address_line', value: address.address_1 || '' },
      { key: 'city', value: address.city || '' },
      { key: 'country', value: address.country || '' },
      { key: 'phone', value: address.phone || '' },

      { key: 'order_placed_at_ms', value: timestamp },
      { key: 'location_lat', value: meta.location_lat ?? null },
      { key: 'location_lng', value: meta.location_lng ?? null },
      { key: 'time_slot', value: meta.time_slot || '' },
    ];

    // ---- Create Woo order ----
    const wooRes = await wooAxios.post('orders', {
      payment_method: 'stripe',               // ALWAYS STRIPE for subscriptions
      payment_method_title: 'Card',
      set_paid: false,                        // Allow Stripe manual-capture flow
      billing: address,
      shipping: address,
      line_items: lineItems,
      meta_data,
    });

    const wooOrder = wooRes.data;
    const payUrl = `${WOO_BASE}/checkout/order-pay/${wooOrder.id}/?pay_for_order=true&key=${wooOrder.order_key}`;

    // ---- Create Firestore subscription master record ----
    const docRef = admin.firestore().collection('orders').doc();
    await docRef.set({
      docId: docRef.id,
      userId,
      wooOrderId: wooOrder.id,
      wooOrderKey: wooOrder.order_key,
      payUrl,

      items: cartItems,
      wooLineItems: wooOrder.line_items.map(li => ({
        name: li.name,
        quantity: li.quantity,
        total: li.total,
      })),

      isSubscription: true,
      subscriptionActive: true,
      cycle_number: 1,

      // Parent subscription has no parent; we write all variants once
      parentId: null,
      parent_subscription_id: null,
      parentSubscriptionId: null,

      status: 'pending',
      paymentStatus: 'initiated',
      gateway: 'stripe',

      address: {
        address_1: address.address_1,
        city: address.city,
        country: address.country,
        phone: address.phone,
        lat: meta.location_lat ?? null,
        lng: meta.location_lng ?? null,
      },

      meta,
      total: wooOrder.total,
      currency: wooOrder.currency,

      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ---- Write Firestore docId back to Woo ----
    await wooAxios.put(`orders/${wooOrder.id}`, {
      meta_data: [
        ...meta_data.filter(m => m.key !== 'cadeli_order_doc_id'),
        { key: 'cadeli_order_doc_id', value: docRef.id },
      ],
    });

    // ---- Start chat thread ----
    await ensureChatAndSystemMessage(
      docRef.id,
      userId,
      'Subscription created. Please authorize payment to proceed.',
      'pending'
    );

    return {
      docId: docRef.id,
      wooOrderId: wooOrder.id,
      orderKey: wooOrder.order_key,
      payUrl,
      total: wooOrder.total,
      currency: wooOrder.currency,
    };

  } catch (err) {
    console.error('createWooOrderFromCart error →', err.message);
    throw new HttpsError('internal', err.message);
  }
});

    exports.debugWhoAmI = onCall(async (req) => {
      logAuth('debugWhoAmI', req);
      if (!req.auth) throw new HttpsError('unauthenticated', 'Not signed in');

      let email = null;
      try {
        const doc = await admin.firestore().collection('users').doc(req.auth.uid).get();
        if (doc.exists) email = doc.data()?.email || null;
      } catch (e) {
        console.log('debugWhoAmI: firestore read error', e.message);
      }

      return {
        uid: req.auth.uid,
        emailFromFirestore: email,
        emailFromToken: req.auth.token?.email || null,
        signInProvider: req.auth.token?.firebase?.sign_in_provider || null,
        hasAuthHeader: Boolean(req.rawRequest?.headers?.authorization),
        project: process.env.GCLOUD_PROJECT,
        region: 'us-central1',
        timestamp: new Date().toISOString(),
      };
    });

    exports.getPendingOrders = onCall(async (req) => {
      logAuth('getPendingOrders', req);
      await checkAdmin(req);

      try {
        const response = await wooAxios.get('orders', { params: { status: 'pending', per_page: 50 } });
        return response.data;
      } catch (error) {
        console.error('getPendingOrders error:', error.response?.data || error.message);
        throw new HttpsError('internal', error.message);
      }
    });

    exports.wooWebhook = onRequest(async (req, res) => {
      if (req.method !== 'POST') return res.status(405).send('Only POST allowed');
      try {
        const body = req.body || {};
        const wooOrderId = body.id;
        const status = body.status;
        if (!wooOrderId || !status) return res.status(200).send('noop');

        const snap = await admin.firestore().collection('orders')
        .where('wooOrderId', '==', Number(wooOrderId)).limit(1).get();

        if (!snap.empty) {
          const ref = snap.docs[0].ref;
          const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };

          //mark authorized on “on-hold”, capture only for Stripe
          const doc = snap.docs[0];
          const orderData = doc.data() || {};
          const gateway = orderData.gateway || orderData.paymentMethod || 'stripe';

          // Try to save Stripe PI id from Woo meta if present
          const metaArr = Array.isArray(body.meta_data) ? body.meta_data : [];
          const getMeta = (k) => {
            const m = metaArr.find((x) => x && x.key === k);
            return m ? m.value : null;
          };
          const paymentIntentId =
            getMeta('_stripe_intent_id') ||
            getMeta('_stripe_payment_intent_id') ||
            getMeta('payment_intent_id') ||
            getMeta('stripe_intent_id');


         // 1) Card authorized (manual-capture): Woo sets "on-hold"
         if (status === 'on-hold') {
           if (gateway === 'stripe') {
             updates.paymentStatus = 'authorized'; // not captured yet
           }
         }

         // 2) Admin Accept → Woo goes to processing/completed → Stripe captures
         if (status === 'processing' || status === 'completed') {
           if (gateway === 'stripe') {
             updates.paymentStatus = 'paid'; // only card becomes paid
           }
           updates.status = 'active'; // business goes live for both card & COD
         }

         // 3) Failure / cancel / refund
         if (status === 'failed' || status === 'cancelled' || status === 'refunded') {
           updates.paymentStatus = 'failed';
           // optional: also reflect business status
           // updates.status = 'rejected';
         }

         // 4) Persist PI id if present (once)
         if (paymentIntentId && !orderData.paymentIntentId) {
           updates.paymentIntentId = paymentIntentId;
         }

         await ref.update(updates);

        }
        res.status(200).send('ok');
      } catch (e) {
        console.error('webhook error', e);
        res.status(200).send('err');
      }
    });

    exports.createPaymentSheet = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (req) => {
  if (!req.auth) {
    throw new HttpsError('unauthenticated', 'Not logged in');
  }

  const { orderId } = req.data || {};
  if (!orderId) {
    throw new HttpsError('invalid-argument', 'orderId is required');
  }

  const stripe = require('stripe')(STRIPE_SECRET_KEY.value());

  // Fetch order
  const orderDoc = await admin.firestore().collection('orders').doc(orderId).get();
  if (!orderDoc.exists) {
    throw new HttpsError('not-found', 'Order not found.');
  }
  const order = orderDoc.data();

  // Parse total reliably
  const rawTotal = order?.total;
  const totalNum = typeof rawTotal === 'number'
    ? rawTotal
    : parseFloat(String(rawTotal ?? ''));

  if (!Number.isFinite(totalNum) || totalNum <= 0) {
    throw new HttpsError('failed-precondition', 'Order total is invalid.');
  }

  const amount = Math.round(totalNum * 100);
  const currency = String(order.currency || 'eur').toLowerCase();

  console.log('createPaymentSheet:', { orderId, amount, currency });

  // Ensure single Stripe customer for user
  const uid = req.auth.uid;
  const userRef = admin.firestore().collection('users').doc(uid);
  const userSnap = await userRef.get();
  let stripeCustomerId = userSnap.data()?.stripeCustomerId;

  if (!stripeCustomerId) {
    const userRecord = await admin.auth().getUser(uid);
    const customer = await stripe.customers.create({ email: userRecord.email });
    stripeCustomerId = customer.id;
    await userRef.set({ stripeCustomerId }, { merge: true });
  }

  // Ephemeral key
  const ephemeralKey = await stripe.ephemeralKeys.create(
    { customer: stripeCustomerId },
    { apiVersion: '2024-06-20' }
  );

  // PaymentIntent — AUTH ONLY (manual capture)
  const paymentIntent = await stripe.paymentIntents.create({
    amount,
    currency,
    customer: stripeCustomerId,
    capture_method: 'manual',
    automatic_payment_methods: { enabled: true },
    metadata: { orderId },
  });

  // Save PI id early (optional, but helpful)
  await orderDoc.ref.update({
    paymentIntentId: paymentIntent.id,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    paymentIntent: paymentIntent.client_secret,
    ephemeralKey: ephemeralKey.secret,
    customer: stripeCustomerId,
  };
});

    exports.adminAcceptOrder = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (req) => {
  await checkAdmin(req);

  const { docId } = req.data || {};
  if (!docId) throw new HttpsError('invalid-argument', 'docId required');

  const ref = admin.firestore().collection('orders').doc(docId);
  const snap = await ref.get();
  const data = snap.data() || {};

  if (data.paymentStatus !== 'authorized') {
    throw new HttpsError('failed-precondition', 'Payment is not authorized yet.');
  }

  if (!data.paymentIntentId) {
    throw new HttpsError('failed-precondition', 'Missing PaymentIntent ID.');
  }

  const stripe = require('stripe')(STRIPE_SECRET_KEY.value());

  try {
    await stripe.paymentIntents.capture(data.paymentIntentId);
  } catch (err) {
    console.error('Stripe capture failed:', err.message);
    throw new HttpsError('internal', 'Failed to capture payment.');
  }

  await ref.update({
    paymentStatus: 'paid',
    status: 'active',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // --------- Parent/child aware chat message ----------
  const cycle = Number(data.cycle_number || 1);
  const parentId =
    data.parent_subscription_id ||
    data.parentSubscriptionId ||
    data.parentId ||
    docId;

  const msg = cycle > 1
    ? `Cycle ${cycle} approved. Driver notified.`
    : 'Subscription approved. First cycle is now active.';

  await ensureChatAndSystemMessage(
    parentId,
    data.userId,
    msg,
    'active'
  );

  return { ok: true };
});

    exports.adminRejectOrder = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (req) => {
      logAuth('adminRejectOrder', req, {
        docId: req.data?.docId,
        orderId: req.data?.orderId,
      });
      await checkAdmin(req);

      const { docId, orderId } = req.data || {};
      if (!docId && !orderId) throw new HttpsError('invalid-argument', 'docId or orderId required');

      // find Firestore order
      let ref = null;
      if (docId) {
        ref = admin.firestore().collection('orders').doc(docId);
      } else {
        const snap = await admin.firestore().collection('orders')
          .where('wooOrderId', '==', Number(orderId)).limit(1).get();
        if (!snap.empty) ref = snap.docs[0].ref;
      }
      if (!ref) throw new HttpsError('not-found', 'Order not found');

      const data = (await ref.get()).data() || {};
      const gw = data.gateway || data.paymentMethod || 'stripe';
      const wooId = orderId || data.wooOrderId;

      // Stripe: if authorized, cancel PI to release funds
      if (gw === 'stripe' && data.paymentStatus === 'authorized' && data.paymentIntentId) {
        const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
        try { await stripe.paymentIntents.cancel(data.paymentIntentId); } catch (e) { console.log('cancel PI failed', e.message); }
      }

      // Woo: set cancelled (best effort)
      if (wooId) {
        try { await wooAxios.put(`orders/${wooId}`, { status: 'cancelled' }); } catch (_) {}
      }

      await ref.update({
        status: 'rejected',
        paymentStatus: (gw === 'stripe' ? 'voided' : 'failed'),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Post system message to tell customer, then delete the chat
      try {
        await ensureChatAndSystemMessage(ref.id, data.userId, 'Sorry, the order cannot be processed at this time.', 'rejected');
      } catch (_) {}

      try { await deleteChatWithMessages(ref.id); } catch (_) {}


      return { ok: true };
    });

    exports.getWooOrderSummary = onCall(async (req) => {

  const { orderId } = req.data || {};
  if (!orderId) {
    throw new HttpsError('invalid-argument', 'orderId is required');
  }

  try {
    // WooCommerce: GET /orders/{id}
    const { data: o } = await wooAxios.get(`orders/${orderId}`);

    // Infer payment status:
    // - Woo "status" can be: pending, processing, on-hold, completed, cancelled, refunded, failed
    // - Consider "processing" or "completed" as paid (date_paid set).
    const isPaid = !!o.date_paid || ['processing', 'completed'].includes(o.status);

    return {
      orderId: o.id,
      wooStatus: o.status,                         // e.g., 'processing'
      paid: isPaid,                                // true/false
      paymentMethod: o.payment_method_title || o.payment_method || null,
      total: o.total,
      currency: o.currency,
      transactionId: o.transaction_id || null,
      datePaid: o.date_paid || null,
      dateCompleted: o.date_completed || null,
    };
  } catch (err) {
    console.error('getWooOrderSummary error', err?.response?.data || err.message);
    throw new HttpsError('internal', 'Failed to fetch Woo order');
  }
});

// Utility: create a new Woo order from a "template" (the original subscription doc)
// and write a new Firestore order occurrence. Returns {docId, wooOrderId, payUrl, ...}
    async function spawnSubscriptionOrderFromTemplate(templateDoc, parentId, nextCycleNumber) {
  const data = templateDoc.data() || {};
  const userId = data.userId;
  const items = Array.isArray(data.items) ? data.items : [];
  const address = data.address || {};
  const meta = Object.assign({}, data.meta || {});

  // 1) Resolve billing email (best-effort)
  let billingEmail =
    meta.customer_email ||
    (address && address.email) ||
    null;

  if (!billingEmail && userId) {
    try {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      billingEmail = userDoc.exists ? (userDoc.data().email || null) : null;
    } catch (_) {}
    if (!billingEmail) {
      try {
        const u = await admin.auth().getUser(userId);
        billingEmail = u.email || null;
      } catch (_) {}
    }
  }
  if (!billingEmail) billingEmail = 'noemail@cadeli.app';

  // 2) Ensure subscription metadata
  meta.order_placed_at_ms = Date.now();
  meta.delivery_type = 'subscription';
  meta.parentId = parentId;
  meta.cycle_number = nextCycleNumber;

  const paymentMethod = (data.gateway || data.paymentMethod || 'stripe');

  const line_items = items.map(it => ({
    product_id: Number(it.id || it.product_id || 0),
    quantity: Number(it.quantity || 1),
  }));

  const meta_data = [
    { key: 'firebase_uid', value: userId },
    { key: 'cadeli_order_doc_id', value: 'PENDING_SET' },
    { key: 'delivery_type', value: 'subscription' },
    { key: 'customer_name', value: meta.customer_name || '' },
    { key: 'address_line', value: meta.address_line || address.address_1 || '' },
    { key: 'city',        value: meta.city || address.city || '' },
    { key: 'country',     value: meta.country || address.country || '' },
    { key: 'phone',       value: meta.phone || address.phone || '' },
    { key: 'order_placed_at_ms', value: meta.order_placed_at_ms },
    { key: 'location_lat', value: meta.location_lat ?? null },
    { key: 'location_lng', value: meta.location_lng ?? null },
    { key: 'time_slot',    value: meta.time_slot || '' },
    { key: 'frequency',    value: meta.frequency || 'Weekly' },
    { key: 'preferred_day', value: meta.preferred_day || '' },
    { key: 'parentId', value: parentId },
    { key: 'cycle_number', value: nextCycleNumber },
  ];

  const orderPayload = {
    payment_method: paymentMethod, // 'stripe' or 'cod'
    payment_method_title: (paymentMethod === 'cod' ? 'Cash on Delivery' : 'Stripe'),
    set_paid: false,
    billing: {
      first_name: data?.billing?.first_name || '',
      last_name:  data?.billing?.last_name  || '',
      address_1:  address.address_1 || '',
      city:       address.city || '',
      country:    address.country || '',
      email:      billingEmail,
      phone:      address.phone || '',
    },
    shipping: {
      first_name: data?.shipping?.first_name || '',
      last_name:  data?.shipping?.last_name  || '',
      address_1:  address.address_1 || '',
      city:       address.city || '',
      country:    address.country || '',
      email:      billingEmail,
      phone:      address.phone || '',
    },
    line_items,
    meta_data,
  };

  const wooRes = await wooAxios.post('orders', orderPayload);
  const wooOrder = wooRes.data;
  const payUrl = `${WOO_BASE}/checkout/order-pay/${wooOrder.id}/?pay_for_order=true&key=${wooOrder.order_key}`;

  const compactItems = Array.isArray(wooOrder.line_items)
    ? wooOrder.line_items.map(li => ({
        name: li.name,
        quantity: li.quantity,
        total: li.total,
      }))
    : [];

  const occRef = admin.firestore().collection('orders').doc();
  await occRef.set({
    docId: occRef.id,
    // Child subscription order – write all variants so the app & admin pages
    // can read consistently
    parentId: parentId,
    parent_subscription_id: parentId,
    parentSubscriptionId: parentId,

    userId,

    wooOrderId: wooOrder.id,
    wooOrderKey: wooOrder.order_key,
    payUrl,

    wooLineItems: compactItems,
    items,

    status: 'pending',
    paymentStatus: (paymentMethod === 'cod' ? 'unpaid' : 'initiated'),
    isSubscription: true,
    subscriptionActive: true,
    cycle_number: nextCycleNumber,

    address: {
      address_1: address.address_1 || '',
      city: address.city || '',
      country: address.country || '',
      phone: address.phone || '',
      lat: meta.location_lat ?? null,
      lng: meta.location_lng ?? null,
    },

    total: wooOrder.total,
    currency: wooOrder.currency,
    meta,

    paymentMethod: (paymentMethod === 'cod' ? 'cod' : 'card'),
    gateway: paymentMethod,

    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // back-write Firestore doc id to Woo (non-fatal)
  try {
    await wooAxios.put(`orders/${wooOrder.id}`, {
      meta_data: [
        ...meta_data.filter(m => m.key !== 'cadeli_order_doc_id'),
        { key: 'cadeli_order_doc_id', value: occRef.id },
      ],
    });
  } catch (e) {
    console.log('spawnSubscriptionOrderFromTemplate: cannot write cadeli_order_doc_id', e.response?.data || e.message);
  }

// ------ AUTO CREATE PAYMENT INTENT FOR CHILD CYCLE ------
try {
  const totalFloat = parseFloat(String(wooOrder.total || '0'));
  const totalCents = Math.round(totalFloat * 100);
  await createAutoPaymentIntentForCycle(occRef.id, totalCents);
} catch (e) {
  console.log("Failed to create automatic PI:", e.message);
}

  return {
    docId: occRef.id,
    wooOrderId: wooOrder.id,
    payUrl,
    currency: wooOrder.currency,
    total: wooOrder.total,
    cycleNumber: nextCycleNumber,
  };
}

// Post a system message into the ORIGINAL subscription chat thread
    async function postNudgeToChat(subscriptionDocId, message) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  await admin.firestore().collection('chats').doc(subscriptionDocId).collection('messages').add({
    senderId: 'admin-system',
    senderRole: 'system',
    type: 'system',
    text: message,
    createdAt: now,
  });
  await admin.firestore().collection('chats').doc(subscriptionDocId).set({
    lastMessage: message,
    lastSenderId: 'admin-system',
    updatedAt: now,
  }, { merge: true });
}
// HTTP endpoint you can call from Cloud Scheduler daily (e.g., 07:00 Europe/Athens)

    exports.stripeWebhook = onRequest({ secrets: [STRIPE_WEBHOOK_SECRET] }, async (req, res) => {
  let event;
  try {
    event = require('stripe').webhooks.constructEvent(
      req.rawBody,
      req.headers['stripe-signature'],
      STRIPE_WEBHOOK_SECRET.value()
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.sendStatus(400);
  }

  const db = admin.firestore();

  // ---------------------
  // 1) AUTHORIZED (manual capture ready)
  // ---------------------
  if (event.type === 'payment_intent.amount_capturable_updated') {
    const pi = event.data.object;
    const orderId = pi.metadata?.orderId;

    if (!orderId) {
      console.log('Stripe webhook amount_capturable_updated without orderId');
      return res.sendStatus(200);
    }

    await db.collection('orders').doc(orderId).update({
      paymentStatus: 'authorized',
      paymentIntentId: pi.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`🔵 Stripe → Authorized (capturable) for order ${orderId}`);
  }

  // ---------------------
  // 2) CAPTURED / PAID
  // ---------------------
  if (event.type === 'payment_intent.succeeded') {
    const pi = event.data.object;
    const orderId = pi.metadata?.orderId;

    if (!orderId) {
      console.log('Stripe webhook succeeded without orderId');
      return res.sendStatus(200);
    }

    const ref = db.collection('orders').doc(orderId);
    const snap = await ref.get();
    const data = snap.data() || {};

    await ref.update({
      paymentStatus: 'paid',
      status: 'active',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`🟢 Stripe → Payment captured for order ${orderId}`);

    // ---------- SET DEFAULT CARD FOR FUTURE CYCLES ----------
    try {
      if (data.isSubscription && data.userId && pi.payment_method) {
        const userRef = db.collection('users').doc(data.userId);
        const userDoc = await userRef.get();
        const stripeCustomerId = userDoc.data()?.stripeCustomerId;

        if (stripeCustomerId) {
          const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
          await stripe.customers.update(stripeCustomerId, {
            invoice_settings: { default_payment_method: pi.payment_method },
          });
          console.log(`✅ Default payment method set for customer ${stripeCustomerId}`);
        } else {
          console.log('No stripeCustomerId on user, cannot set default PM.');
        }
      }
    } catch (err) {
      console.log('Failed to set default payment method:', err.message);
    }
  }

  // ---------------------
  // 3) PAYMENT FAILED
  // ---------------------
  if (event.type === 'payment_intent.payment_failed') {
    const pi = event.data.object;
    const orderId = pi.metadata?.orderId;

    if (!orderId) {
      console.log('Stripe webhook payment_failed without orderId');
      return res.sendStatus(200);
    }

    const ref = db.collection('orders').doc(orderId);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log('payment_failed: order not found', orderId);
      return res.sendStatus(200);
    }

    const data = snap.data() || {};
    const userId = data.userId;

    // Normalise parent subscription ID – support all historical field names
    const parentId =
      data.parent_subscription_id ||
      data.parentSubscriptionId ||
      data.parentId ||
      orderId;


    // Mark this order as failed
    await ref.update({
      paymentStatus: 'failed',
      status: data.status === 'pending' ? 'payment_failed' : data.status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // If not a subscription → just stop here
        if (
          !data.isSubscription &&
          !data.parent_subscription_id &&
          !data.parentSubscriptionId &&
          !data.parentId
        ) {
          console.log(`payment_failed: non-subscription order ${orderId}`);
          return res.sendStatus(200);
        }


    // Increment failure counter on parent subscription
    const parentRef = db.collection('orders').doc(parentId);
    const parentSnap = await parentRef.get();
    if (!parentSnap.exists) {
      console.log('payment_failed: parent subscription not found', parentId);
      return res.sendStatus(200);
    }

    const parentData = parentSnap.data() || {};
    const currentFails = Number(parentData.failedPaymentCount || 0) + 1;

    const parentUpdates = {
      failedPaymentCount: currentFails,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // If 3 or more failures → cancel subscription
    if (currentFails >= 3) {
      parentUpdates.subscriptionActive = false;
      parentUpdates.status = 'payment_failed';

      await parentRef.update(parentUpdates);

      // Cancel all pending/active child cycles
      const childrenSnap = await db.collection('orders')
        .where('parentId', '==', parentId)
        .where('status', 'in', ['pending', 'active'])
        .get();

      const batch = db.batch();
      childrenSnap.forEach((d) => {
        batch.update(d.ref, {
          status: 'payment_failed',
          subscriptionActive: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();

      // System message to explain
      await ensureChatAndSystemMessage(
        parentId,
        userId,
        'Your payment failed multiple times. The subscription has been stopped. Please update your payment method if you wish to restart.',
        'payment_failed'
      );

      console.log(`🔴 Subscription ${parentId} cancelled after repeated payment failures.`);
    } else {
      // Soft warning, subscription still active
      await parentRef.update(parentUpdates);

      await ensureChatAndSystemMessage(
        parentId,
        userId,
        `Your last payment attempt failed. Please update your payment method. We will try again soon. (Failure #${currentFails})`,
        parentData.status || 'pending'
      );

      console.log(`🟠 payment_failed: subscription ${parentId} failure #${currentFails}`);
    }
  }

  return res.sendStatus(200);
});

// ------------------------------------------------------------
// Create automatic PaymentIntent for subscription child cycles
// ------------------------------------------------------------
    async function createAutoPaymentIntentForCycle(orderDocId, amountInCents) {
  const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
  const db = admin.firestore();

  const orderSnap = await db.collection('orders').doc(orderDocId).get();
  const order = orderSnap.data() || {};
  const uid = order.userId;

  // Fetch Stripe customer
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  const stripeCustomerId = userDoc.data()?.stripeCustomerId;

  if (!stripeCustomerId) {
    console.log("❌ No stripeCustomerId found for user", uid);
    return null;
  }

  // Retrieve default payment method
  const cust = await stripe.customers.retrieve(stripeCustomerId);
  const defaultPM = cust.invoice_settings?.default_payment_method;

  if (!defaultPM) {
    console.log("❌ No default payment method found, cannot auto-authorize.");
    return null;
  }

  // Create PI (manual capture)
  const pi = await stripe.paymentIntents.create({
    amount: amountInCents,
    currency: 'eur',
    customer: stripeCustomerId,
    payment_method: defaultPM,
    capture_method: 'manual',
    confirm: true,
    metadata: { orderId: orderDocId }
  });

  await orderSnap.ref.update({
    paymentIntentId: pi.id,
    paymentStatus: 'initiated',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return pi.id;
}


    exports.onChatMessageCreated = onDocumentCreated('chats/{chatId}/messages/{msgId}', async (event) => {
  const chatId = event.params.chatId;
  const msg = event.data?.data();
  if (!msg) return;

  const db = admin.firestore();
  const chatRef = db.collection('chats').doc(chatId);
  const chatSnap = await chatRef.get();
  const chat = chatSnap.data() || {};

  const senderId = String(msg.senderId || 'system');
  const text = String(msg.text || '');

  // update thread metadata
  const updates = {
    lastMessage: text,
    lastSenderId: senderId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const customerId = String(chat.customerId || '');

  // increment unread for the opposite side (customer vs everyone-else)
  if (senderId === customerId) {
    updates.unreadForAdmin = admin.firestore.FieldValue.increment(1);
  } else {
    updates.unreadForCustomer = admin.firestore.FieldValue.increment(1);
  }
  await chatRef.set(updates, { merge: true });

  // notify all other participants (real UIDs), not the sender, not system, not legacy 'ADMIN'
  const participants = Array.isArray(chat.participants) ? chat.participants.map(String) : [];
  const others = participants.filter(
    (uid) => uid && uid !== senderId && uid !== 'admin-system' && uid !== 'ADMIN'
  );

  for (const uid of others) {
    await pushToUser(uid, 'New message', text, { type: 'chat', chat_id: chatId });
  }
});

    exports.fixChatParticipantsOnce = onCall(async (req) => {
  await checkAdmin(req); // only real admins may run it

  const db = admin.firestore();
  const cfg = await db.collection('config').doc('admins').get();
  const adminUids = Array.isArray(cfg.data()?.uids) ? cfg.data().uids.map(String) : [];
  if (!adminUids.length) return { updated: 0, note: 'No admin uids in /config/admins' };

  const snap = await db.collection('chats').get();
  let updated = 0, cleaned = 0;

  for (const d of snap.docs) {
    const m = d.data() || {};
    const curr = Array.isArray(m.participants) ? m.participants.map(String) : [];
    const next = Array.from(new Set([...curr, ...adminUids]))
                      .filter(uid => uid && uid !== 'ADMIN');

    if (JSON.stringify(next.slice().sort()) !== JSON.stringify(curr.slice().sort())) {
      await d.ref.update({ participants: next });
      updated++;
    }

    if (m.adminId === 'ADMIN' && adminUids[0]) {
      await d.ref.update({ adminId: adminUids[0] });
      cleaned++;
    }
  }
  return { total: snap.size, participantsUpdated: updated, adminIdCleaned: cleaned };
});

    async function deleteChatWithMessages(orderId) {
      const chatRef = admin.firestore().collection('chats').doc(orderId);
      const msgs = await chatRef.collection('messages').get();
      const batch = admin.firestore().batch();
      msgs.forEach(d => batch.delete(d.ref));
      batch.delete(chatRef);
      await batch.commit();
    }

    exports.onOrderDeleted = onDocumentDeleted('orders/{orderId}', async (event) => {
      const orderId = event.params.orderId;
      try {
        await deleteChatWithMessages(orderId);
        console.log('Deleted chat for removed order', orderId);
      } catch (e) {
        console.error('Failed deleting chat for order', orderId, e.message);
      }
    });

    exports.listPaymentMethods = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
  const uid = req.auth.uid;
  const userRef = admin.firestore().collection('users').doc(uid);
  const userDoc = await userRef.get();
  let customerId = userDoc.data()?.stripeCustomerId;

  // 🔹 create if missing
  if (!customerId) {
    const authUser = await admin.auth().getUser(uid);
    const customer = await stripe.customers.create({ email: authUser.email });
    customerId = customer.id;
    await userRef.set({ stripeCustomerId: customerId }, { merge: true });
  }

  // 🔹 get attached cards
  const methods = await stripe.paymentMethods.list({
    customer: customerId,
    type: 'card',
  });

  return methods.data.map(pm => ({
    id: pm.id,
    brand: pm.card?.brand,
    last4: pm.card?.last4,
    exp_month: pm.card?.exp_month,
    exp_year: pm.card?.exp_year,
  }));
});

    exports.addPaymentMethod = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (req) => {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Not logged in');
      const stripe = require('stripe')(STRIPE_SECRET_KEY.value());

      // Find Stripe customer or create one
      const userRef = admin.firestore().collection('users').doc(req.auth.uid);
      const userDoc = await userRef.get();
      let customerId = userDoc.data()?.stripeCustomerId;

      if (!customerId) {
        const user = await admin.auth().getUser(req.auth.uid);
        const customer = await stripe.customers.create({ email: user.email });
        customerId = customer.id;
        await userRef.update({ stripeCustomerId: customerId });
      }

      // Create a SetupIntent (for adding new cards)
      const setupIntent = await stripe.setupIntents.create({
        customer: customerId,
        automatic_payment_methods: { enabled: true },
      });

      return {
        clientSecret: setupIntent.client_secret,
        customerId,
      };
    });

    exports.deletePaymentMethod = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (req) => {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Not logged in');
      const { id } = req.data || {};
      if (!id) throw new HttpsError('invalid-argument', 'payment method id required');

      const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
      await stripe.paymentMethods.detach(id);
      return { ok: true };
    });

    exports.setDefaultPaymentMethod = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Not logged in');
  const { id } = req.data || {};
  if (!id) throw new HttpsError('invalid-argument', 'payment method id required');

  const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
  const uid = req.auth.uid;

  const userRef = admin.firestore().collection('users').doc(uid);
  const userDoc = await userRef.get();
  const customerId = userDoc.data()?.stripeCustomerId;

  if (!customerId) {
    throw new HttpsError('failed-precondition', 'No Stripe customer found for this user.');
  }

  await stripe.customers.update(customerId, {
    invoice_settings: { default_payment_method: id },
  });

  return { ok: true };
});

    exports.markDelivered = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (req) => {
  await checkAdmin(req);

  const { docId } = req.data || {};
  if (!docId) throw new HttpsError('invalid-argument', 'docId required');

  const db = admin.firestore();
  const ref = db.collection('orders').doc(docId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError('not-found', 'Order not found');
  }

  const data = snap.data() || {};
  const userId = data.userId;
  const currentCycle = Number(data.cycle_number || 1);

  // Parent subscription ID (if this is the parent itself, parent is docId)
  const parentId =
    data.parent_subscription_id ||
    data.parentSubscriptionId ||
    data.parentId ||
    docId;


  // 1) Mark this cycle as delivered/completed
  await ref.update({
    status: 'completed',
    deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await ensureChatAndSystemMessage(
    docId,
    userId,
    `Cycle ${currentCycle} delivered successfully.`,
    'completed'
  );

  // 2) If subscription is not active on parent, do NOT create further cycles
  const parentRef = db.collection('orders').doc(parentId);
  const parentSnap = await parentRef.get();
  const parentData = parentSnap.exists ? (parentSnap.data() || {}) : {};

  if (parentSnap.exists && parentData.subscriptionActive === false) {
    console.log(`Subscription ${parentId} inactive, not spawning new cycle.`);
    return { ok: true, message: 'Delivered, but subscription inactive. No new cycle created.' };
  }

  // 3) Spawn next cycle (nextCycleNumber = current + 1)
  const nextCycleNumber = currentCycle + 1;

  const result = await spawnSubscriptionOrderFromTemplate(
    snap,
    parentId,
    nextCycleNumber
  );

  // 4) Notify via chat on the parent thread
  await ensureChatAndSystemMessage(
    parentId,
    userId,
    `Cycle ${nextCycleNumber} created and is now pending. Please confirm payment when prompted.`,
    'pending'
  );

  return {
    ok: true,
    nextCycle: nextCycleNumber,
    childDocId: result.docId,
    wooOrderId: result.wooOrderId,
  };
});

    exports.cancelSubscription = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Not logged in');

  const { docId } = req.data || {};
  if (!docId) throw new HttpsError('invalid-argument', 'docId required');

  const db = admin.firestore();
  const ref = db.collection('orders').doc(docId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Order not found');

  const data = snap.data() || {};

  if (!data.isSubscription) {
    throw new HttpsError('failed-precondition', 'Not a subscription order.');
  }
  if (data.userId !== req.auth.uid) {
    throw new HttpsError('permission-denied', 'You can only cancel your own subscription.');
  }

  // 1) Mark parent subscription cancelled
  await ref.update({
    subscriptionActive: false,
    status: 'cancelled',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2) Cancel all pending/active child cycles (parentId + older parent_subscription_id)
  const byParentIdSnap = await db.collection('orders')
    .where('parentId', '==', docId)
    .where('status', 'in', ['pending', 'active'])
    .get();

  const byLegacySnap = await db.collection('orders')
    .where('parent_subscription_id', '==', docId)
    .where('status', 'in', ['pending', 'active'])
    .get();

  const batch = db.batch();

  byParentIdSnap.forEach((d) => {
    batch.update(d.ref, {
      status: 'cancelled',
      subscriptionActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  byLegacySnap.forEach((d) => {
    batch.update(d.ref, {
      status: 'cancelled',
      subscriptionActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await batch.commit();


  // 3) Tell the customer via chat
  await ensureChatAndSystemMessage(
    docId,
    data.userId,
    'Subscription cancelled. No further cycles will be created.',
    'cancelled',
  );

  return { ok: true };
});

    exports.updateTruckLocation = onCall(async (req) => {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Not logged in');
      await checkAdmin(req);

      const { lat, lng } = req.data || {};
      if (!lat || !lng) throw new HttpsError('invalid-argument', 'lat/lng required');

      await admin.firestore().collection('config').doc('truckLocation')
        .set({
          lat,
          lng,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: req.auth.uid
        }, { merge: true });

      return { ok: true };
    });






