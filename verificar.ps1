# Ejecuta las pruebas de antes y después y guarda el resultado en evidencias\
# Uso:  powershell -ExecutionPolicy Bypass -File .\verificar.ps1 -Etiqueta antes
#       powershell -ExecutionPolicy Bypass -File .\verificar.ps1 -Etiqueta despues
param([string]$Etiqueta = "prueba")

$base = "http://localhost:8080"
$carpeta = Join-Path $PSScriptRoot "evidencias"
New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
$archivo = Join-Path $carpeta ("verificacion_{0}_{1}.txt" -f $Etiqueta, (Get-Date -Format "yyyy-MM-dd_HHmm"))

function Get-Codigo([string]$Url, [string]$Metodo = "GET", [string]$Cuerpo = "") {
    $parametros = @("-s", "-o", "NUL", "-w", "%{http_code}", "-X", $Metodo, $Url)
    if ($Cuerpo) { $parametros += @("-d", $Cuerpo) }
    (& curl.exe @parametros)
}

$lineas = New-Object System.Collections.Generic.List[string]
$lineas.Add("Verificación '$Etiqueta' - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lineas.Add("Objetivo: $base")
$lineas.Add("")

$pruebas = @(
    @("xmlrpc.php (H-14)", "$base/xmlrpc.php"),
    @("REST: lista de usuarios (T-02)", "$base/wp-json/wp/v2/users"),
    @("wp-cron.php (T-20)", "$base/wp-cron.php"),
    @("readme.html (T-17)", "$base/readme.html"),
    @("Enumeración ?author=1 (T-02)", "$base/?author=1"),
    @("WAF: XSS en la búsqueda (H-24)", "$base/?s=%3Cscript%3Ealert(1)%3C/script%3E"),
    @("WAF: SQLi en un parámetro (H-24)", "$base/?id=1%27%20OR%20%271%27=%271")
)
foreach ($p in $pruebas) {
    $lineas.Add(("{0,-38} HTTP {1}" -f $p[0], (Get-Codigo $p[1])))
}

$codigos = 1..12 | ForEach-Object { Get-Codigo "$base/wp-login.php" "POST" "log=prueba&pwd=prueba" }
$lineas.Add(("{0,-38} {1}" -f "Login: 12 intentos seguidos (H-15)", ($codigos -join " ")))

foreach ($puerto in 3306, 8080, 8443) {
    $ok = (Test-NetConnection -ComputerName 127.0.0.1 -Port $puerto -WarningAction SilentlyContinue).TcpTestSucceeded
    $estado = if ($ok) { "abierto" } else { "cerrado" }
    $lineas.Add(("{0,-38} {1}" -f "Puerto $puerto (H-20, H-23)", $estado))
}

$lineas.Add("")
$lineas.Add("Cabeceras de la portada:")
foreach ($l in (& curl.exe -s -I "$base/")) {
    if ($l -match "^(HTTP|Server|X-Powered-By|X-Frame-Options|X-Content-Type-Options|Strict-Transport-Security|Content-Security-Policy|Referrer-Policy)") {
        $lineas.Add("  $l")
    }
}

$lineas | Out-File -Encoding utf8 $archivo
$lineas | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Guardado en $archivo"
