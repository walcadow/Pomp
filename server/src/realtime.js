// Anlık bağlantı (Socket.io): yeni mesaj, yeni eşleşme, "yazıyor..." bildirimleri.
const { Server } = require('socket.io');
const { verifyToken } = require('./auth');
const db = require('./db');

let io = null;

function init(httpServer) {
  io = new Server(httpServer, { cors: { origin: '*' } });

  // Bağlanan herkes geçerli bir giriş anahtarı (token) göndermeli.
  io.use(async (socket, next) => {
    const token = socket.handshake.auth && socket.handshake.auth.token;
    try {
      socket.userId = verifyToken(token);
    } catch {
      return next(new Error('unauthorized'));
    }
    // Yasaklanan (veya silinen) hesaplar yeniden bağlanamasın.
    try {
      const { rows } = await db.query('SELECT is_banned FROM users WHERE id = $1', [socket.userId]);
      if (!rows[0] || rows[0].is_banned) return next(new Error('unauthorized'));
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.userId}`);

    // Socket'leri yükleme döngüsünden kaçınmak için burada istiyoruz.
    const chat = require('./chat');

    socket.on('message:send', async (payload, ack) => {
      try {
        const message = await chat.sendMessage(socket.userId, payload && payload.matchId, payload && payload.body);
        if (typeof ack === 'function') ack({ ok: true, message });
      } catch (err) {
        if (typeof ack === 'function') ack({ ok: false, error: err.status ? err.message : 'Mesaj gönderilemedi.' });
      }
    });

    socket.on('typing', async (payload) => {
      try {
        const match = await chat.getMatchForUser(payload && payload.matchId, socket.userId);
        emitToUser(match.other, 'typing', { matchId: match.id, userId: socket.userId });
      } catch {
        /* geçersiz eşleşme: yok say */
      }
    });

    socket.on('message:read', async (payload) => {
      try {
        await chat.markRead(socket.userId, payload && payload.matchId);
      } catch {
        /* yok say */
      }
    });
  });

  return io;
}

function emitToUser(userId, event, data) {
  if (io) io.to(`user:${userId}`).emit(event, data);
}

function disconnectUser(userId) {
  if (io) io.in(`user:${userId}`).disconnectSockets(true);
}

module.exports = { init, emitToUser, disconnectUser };
