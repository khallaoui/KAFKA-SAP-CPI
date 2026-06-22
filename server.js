const express = require('express');
const { Kafka } = require('kafkajs');
const app = express();
const PORT = 3000;

app.use(express.static('public'));

// 1. CONFIGURATION CONFIGURATION KAFKA
const kafka = new Kafka({
    clientId: 'js-dashboard-client',
    brokers: ['pkc-z9doz.eu-west-1.aws.confluent.cloud:9092'],
    ssl: true,
    sasl: {
        mechanism: 'plain',
        username: 'CNQGVA3MSAJRNGJS',
        password: 'cfltfKy2kf2tt8VIUwIB8+IUC1TkN+EFCh4fn83dXNZmXG7SFi+1ugeTcQsX1CKQ'
    }
});

// Cache en mémoire pour stocker les commandes reçues
let ordersCache = [];

// Un seul consommateur permanent
const consumer = kafka.consumer({ groupId: `abap_fiori_permanent_group` });

async function startKafkaConsumer() {
    try {
        await consumer.connect();
        await consumer.subscribe({ topic: 'orders', fromBeginning: true });
        console.log("📥 Écoute permanente de Confluent Cloud activée...");

        await consumer.run({
            eachMessage: async ({ message }) => {
                try {
                    const payload = JSON.parse(message.value.toString());
                    
                    const newOrder = {
                        offset: message.offset,
                        order_id: payload.order_id || `CMD-${message.offset}`,
                        client_name: payload.client_name || "Client Inconnu",
                        amount: parseFloat(payload.amount || 0),
                        currency: payload.currency || "MAD",
                        status: payload.status || "NEW"
                    };

                    // Évite l'ajout de doublons dans le tableau de ton écran
                    if (!ordersCache.some(o => o.offset === message.offset)) {
                        ordersCache.push(newOrder);
                        console.log(`📦 Nouvelle commande détectée ! ID: ${newOrder.order_id} (Offset: ${newOrder.offset})`);
                        
                        // Garder uniquement les 50 derniers messages en mémoire
                        if (ordersCache.length > 50) ordersCache.shift();
                    }
                } catch (e) {
                    console.log("⚠️ Erreur de lecture d'un message brut");
                }
            },
        });
    } catch (error) {
        console.error("❌ Échec de l'écoute Kafka:", error.message);
    }
}

// Lancement du consommateur en tâche de fond dès le démarrage du serveur
startKafkaConsumer();

// 2. LA ROUTE API DEVIENT INSTANTANÉE
app.get('/api/orders-data', (req, res) => {
    // Renvoie directement les données accumulées en mémoire
    res.json(ordersCache);
});

app.listen(PORT, () => {
    console.log(`🚀 Serveur Web prêt sur http://localhost:3000`);
});