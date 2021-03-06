var wax;

(function() {
 
 var peers = {};
 
 wax = {
    on: function(event, callback) {
        document.addEventListener('pollen:' + event, callback, false);
    },
    off: function(event, callback) {
        document.removeEventListener('pollen:' + event, callback, false);
    },
    trigger: function(event, info) {
        var e = new CustomEvent('pollen:' + event);
        for (var i in info) {
            e[i] = info[i];
        }
        document.dispatchEvent(e);
    },
    sendPrivateMessage: function(peer, message) {
        window.webkit.messageHandlers.privateMessage.postMessage({peer: peer, message:message});
    },
    sendBroadcastMessage: function(message) {
        window.webkit.messageHandlers.broadcastMessage.postMessage(message);
    },
    request: function(url) {
        window.webkit.messageHandlers.request.postMessage(url);
    },
    peers: function() {
        var a = [];
        for(var o in peers) {
            a.push(peers[o]);
        }
        return a;
    },
    connection: 'connect',
    disconnection: 'disconnect',
    privateMessage: 'pm',
    broadcastMessage: 'bm',
    response: 'res',
    request: 'req'
 };
 
 Object.freeze(wax);

 wax.on(wax.connection, function(e) {
   peers[e.id] = e.name;
 });
 
 wax.on(wax.disconnection, function(e) {
   delete peers[e.id];
 });
 
 })();