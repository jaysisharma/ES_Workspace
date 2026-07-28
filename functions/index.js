const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

/**
 * Routing table:
 *
 *  targetRole = 'admin_founder'  → sends to FCM topics: role_admin + role_founder
 *  targetRole = 'staff'          → sends to FCM topic:  role_staff
 *  targetRole = 'all'            → sends to all three topics
 *  targetUserId set              → sends only to that user's FCM token(s)
 */
exports.sendNotificationOnCreate = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const title = data.title ?? "New Notification";
    const body = data.description ?? "";
    const targetRole = data.targetRole ?? "admin_founder";
    const targetUserId = data.targetUserId ?? null;

    const baseMessage = {
      notification: { title, body },
      data: {
        type: data.type ?? "",
        relatedId: data.relatedId ?? "",
        notificationId: event.params.notificationId,
      },
      android: {
        priority: "high",
        notification: { channelId: "order_app_high", sound: "default" },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    };

    const messaging = getMessaging();

    if (targetUserId) {
      // Send to all FCM tokens belonging to this specific user
      const snap = await getFirestore()
        .collection("fcm_tokens")
        .where("userId", "==", targetUserId)
        .get();

      const tokens = snap.docs.map((d) => d.data().token).filter(Boolean);
      if (tokens.length === 0) return;

      // Send individually (sendEachForMulticast handles up to 500 tokens)
      await messaging.sendEachForMulticast({ ...baseMessage, tokens });
      console.log(`Sent to user ${targetUserId} (${tokens.length} token(s))`);
      return;
    }

    // Topic-based routing
    let topics = [];
    if (targetRole === "admin_founder") {
      topics = ["role_admin", "role_founder"];
    } else if (targetRole === "founder") {
      topics = ["role_founder"];
    } else if (targetRole === "admin") {
      topics = ["role_admin"];
    } else if (targetRole === "staff") {
      topics = ["role_staff"];
    } else {
      // 'all'
      topics = ["role_admin", "role_founder", "role_staff"];
    }

    await Promise.all(
      topics.map((topic) =>
        messaging.send({ ...baseMessage, topic }).catch((err) =>
          console.error(`Failed to send to topic ${topic}:`, err)
        )
      )
    );
    console.log(`Sent to topics: ${topics.join(", ")}`);
  }
);
