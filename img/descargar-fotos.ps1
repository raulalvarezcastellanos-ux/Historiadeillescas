# Descarga de Wikimedia Commons las fotos de la web "Illescas, historia por épocas".
# Lee img\temas.txt (clave|búsqueda), guarda cada foto como img\<clave>.jpg y escribe
# img\creditos.js con autor, licencia y enlace de cada imagen.
#
# Uso:  doble clic en descargar-fotos.bat
#   o:  powershell -ExecutionPolicy Bypass -File .\descargar-fotos.ps1            (solo las que faltan)
#       powershell -ExecutionPolicy Bypass -File .\descargar-fotos.ps1 -Forzar    (todas de nuevo)
#       powershell -ExecutionPolicy Bypass -File .\descargar-fotos.ps1 -Solo caridad
# Para elegir una foto concreta, cambia su línea en temas.txt por:  caridad|File:Nombre exacto.jpg
param([switch]$Forzar, [string]$Solo = '')

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ua  = 'IllescasHistoriaWeb/1.0 (web estatica local de historia de Illescas)'
$api = 'https://commons.wikimedia.org/w/api.php'
$utf8 = New-Object Text.UTF8Encoding $false

$temas = [IO.File]::ReadAllLines((Join-Path $dir 'temas.txt'), [Text.Encoding]::UTF8) |
         Where-Object { $_.Trim() -and -not $_.StartsWith('#') }

$credFile = Join-Path $dir 'creditos.json'
$cred = @{}
if (Test-Path $credFile) {
  ([IO.File]::ReadAllText($credFile, [Text.Encoding]::UTF8) | ConvertFrom-Json).psobject.Properties |
    ForEach-Object { $cred[$_.Name] = $_.Value }
}

function Limpia($s) { if (-not $s) { return '' }; return (($s -replace '<[^>]+>', '') -replace '\s+', ' ').Trim() }

$ok = 0; $fallos = 0
foreach ($linea in $temas) {
  $partes = $linea.Split('|', 2)
  $clave = $partes[0].Trim(); $q = $partes[1].Trim()
  if ($Solo -and $clave -ne $Solo) { continue }
  if (-not $Forzar -and -not $Solo -and $cred.ContainsKey($clave) -and (Test-Path (Join-Path $dir $cred[$clave].archivo))) {
    Write-Host "= $clave (ya estaba)"; continue
  }
  try {
    if ($q.StartsWith('File:')) {
      $p = @{ action='query'; titles=$q; prop='imageinfo'; iiprop='url|extmetadata'; iiurlwidth=1280; format='json' }
    } else {
      $p = @{ action='query'; generator='search'; gsrsearch="$q filetype:bitmap"; gsrnamespace=6; gsrlimit=1;
              prop='imageinfo'; iiprop='url|extmetadata'; iiurlwidth=1280; format='json' }
    }
    $r = Invoke-RestMethod -Uri $api -Body $p -UserAgent $ua
    if (-not $r.query) { Write-Warning "Sin resultados para '$clave' ($q)"; $fallos++; continue }
    $pag = $r.query.pages.psobject.Properties | Select-Object -First 1 -ExpandProperty Value
    if (-not $pag.imageinfo) { Write-Warning "No encontrada: '$clave' ($q)"; $fallos++; continue }
    $ii = $pag.imageinfo[0]
    $url = if ($ii.thumburl) { $ii.thumburl } else { $ii.url }
    $ext = [IO.Path]::GetExtension(([uri]$url).AbsolutePath).ToLower()
    if ($ext -eq '.jpeg') { $ext = '.jpg' }
    $archivo = "$clave$ext"
    Invoke-WebRequest -Uri $url -OutFile (Join-Path $dir $archivo) -UserAgent $ua -UseBasicParsing
    $m = $ii.extmetadata
    $cred[$clave] = [ordered]@{
      archivo  = $archivo
      titulo   = $pag.title
      autor    = (Limpia $m.Artist.value)
      licencia = (Limpia $m.LicenseShortName.value)
      origen   = $ii.descriptionurl
    }
    Write-Host "+ $clave  <-  $($pag.title)"
    $ok++
  } catch {
    Write-Warning "Error con '$clave': $($_.Exception.Message)"; $fallos++
  }
  Start-Sleep -Milliseconds 300
}

$json = $cred | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText($credFile, $json, $utf8)
[IO.File]::WriteAllText((Join-Path $dir 'creditos.js'), "window.FOTOS = $json;", $utf8)
Write-Host ""
Write-Host "Listo: $ok descargadas, $fallos con problemas. Abre index.html para ver las fotos."
