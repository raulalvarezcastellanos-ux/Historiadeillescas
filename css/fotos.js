/* Coloca las fotos descargadas (img/creditos.js) en las figuras de la página. */
(function () {
  var F = window.FOTOS || {};
  function credito(f) {
    var s = document.createElement('span');
    var t = [];
    if (f.autor) t.push(f.autor);
    if (f.licencia) t.push(f.licencia);
    s.appendChild(document.createTextNode((t.length ? t.join(' · ') + ' · ' : '')));
    var a = document.createElement('a');
    a.href = f.origen; a.target = '_blank'; a.rel = 'noopener'; a.textContent = 'Wikimedia Commons';
    s.appendChild(a);
    return s;
  }
  document.querySelectorAll('figure[data-foto]').forEach(function (fig) {
    var f = F[fig.getAttribute('data-foto')];
    if (!f || !f.archivo) return;
    var img = fig.querySelector('img');
    img.src = img.getAttribute('data-src') + f.archivo;
    img.onerror = function () { fig.hidden = true; };
    var c = fig.querySelector('.foto-c');
    if (c && !fig.closest('a')) c.appendChild(credito(f));
    fig.hidden = false;
  });
  var lista = document.getElementById('creditos-fotos');
  if (lista) {
    var claves = Object.keys(F).sort();
    if (!claves.length) return;
    lista.innerHTML = '';
    claves.forEach(function (k) {
      var f = F[k], li = document.createElement('li');
      var b = document.createElement('strong'); b.textContent = (f.titulo || k).replace(/^File:/, '') + ' ';
      li.appendChild(b); li.appendChild(credito(f));
      lista.appendChild(li);
    });
  }
})();
