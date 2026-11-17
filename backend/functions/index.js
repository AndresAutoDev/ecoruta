// Autores: Andrés Gómez y Daniel Rodríguez - Proyecto EcoRuta
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
admin.initializeApp();

// Valida coordenadas y confianza del modelo; marca el reporte como válido o en revisión.
exports.validateReport = onDocumentCreated('reports/{id}', async (event) => {
  const d = event.data.data();
  const ok = Math.abs(d.lat) <= 90 && Math.abs(d.lng) <= 180 && d.confidence >= 0.5;
  await event.data.ref.update({ status: ok ? 'validated' : 'review', points: ok ? 10 : 0 });
});
