# PowerShell script to scan 'gallery' subfolders and update 'gallery/gallery_data.js'
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
$folder = Join-Path $root "gallery"

if (-not (Test-Path $folder)) {
    Write-Host "Folder 'gallery' not found!" -ForegroundColor Red
    pause
    exit
}

$exts = @('.jpg', '.jpeg', '.png', '.webp', '.bmp')

# Read existing gallery_data.js to preserve custom captions/descriptions
$existingAlbumsMap = @{}
$existingPhotosMap = @{}
$dataPath = Join-Path $folder "gallery_data.js"
if (Test-Path $dataPath) {
    try {
        $raw = [System.IO.File]::ReadAllText($dataPath, [System.Text.Encoding]::UTF8)
        $match = [regex]::Match($raw, 'window\.GALLERY_ALBUMS\s*=\s*(\[[\s\S]*?\]);\s*(?:\r?\n\s*\/\/|\r?\n\s*window\.GALLERY_IMAGES|$)')
        if ($match.Success) {
            $parsed = $match.Groups[1].Value | ConvertFrom-Json
            foreach ($alb in $parsed) {
                if ($alb.id) { $existingAlbumsMap[$alb.id] = $alb }
                if ($alb.photos) {
                    foreach ($p in $alb.photos) {
                        if ($p.src) { $existingPhotosMap[$p.src] = $p }
                    }
                }
            }
        }
    } catch {}
}

# Pre-defined descriptions for standard category names
$defaultAlbumInfo = @{
    "आध्यात्मिक आयोजन" = "श्रीमद्भागवत कथा, ज्ञान यज्ञ एवं सत्संग के पावन आयोजन।";
    "सेवा का संकल्प" = "जरूरतमंदों, असहायों और निर्धन परिवारों के लिए सेवा कार्य।";
    "भक्ति की संध्या" = "सामूहिक संकीर्तन, सुंदरकांड पाठ और दीप प्रज्ज्वलन के पावन पल।";
    "संस्कार एवं संस्कृति" = "युवा पीढ़ी में सनातन संस्कृति एवं जीवन-मूल्यों का बीजारोपण।";
    "गौ सेवा एवं अन्नदान" = "गौ माता की सेवा, अन्नदान एवं जरूरतमंदों को सहायता।";
    "पावन दर्शन" = "मंदिर दर्शन, महाआरती एवं उत्सवों के दिव्य दर्शन।"
}

# Scan subfolders inside gallery
$subdirs = Get-ChildItem -Path $folder -Directory | Sort-Object Name
$albums = @()
$totalPhotos = 0

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  पवनसुत सेवा संस्थान - फोटो गैलरी ऑटो-अपडेट" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if ($subdirs.Count -gt 0) {
    $dirIndex = 1
    foreach ($dir in $subdirs) {
        $cleanName = $dir.Name -replace '^\d+[\s_-]*', '' -replace '_', ' '
        if ([string]::IsNullOrWhiteSpace($cleanName)) { $cleanName = $dir.Name }

        $albumId = "album_" + $dirIndex
        if ($cleanName -match "आध्यात्मिक") { $albumId = "adhyatmik" }
        elseif ($cleanName -match "सेवा") { $albumId = "seva" }
        elseif ($cleanName -match "भक्ति") { $albumId = "bhakti" }
        elseif ($cleanName -match "संस्कार") { $albumId = "sanskar" }

        $albumFiles = Get-ChildItem -Path $dir.FullName -File | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object {
            if ($_.Name -match '^(आध्यात्मिक|सेवा|भक्ति|संस्कार)') { 0 }
            elseif ($_.BaseName -match '^(\d+)') { [int]$matches[1] }
            else { 9999 }
        }, Name

        if ($albumFiles.Count -eq 0) {
            $fallbackRel = "gallery/" + $dirIndex + ".jpeg"
            if (-not (Test-Path (Join-Path $root $fallbackRel))) {
                $fallbackRel = "Pavansut Seva Emblem.png"
            }
            Write-Host " ! [$cleanName] फोल्डर में कोई फोटो नहीं मिली (डिफ़ॉल्ट फोटो सेट की गई)।" -ForegroundColor Yellow
            $photoList = @([PSCustomObject]@{
                src = $fallbackRel
                title = "$cleanName"
                desc = "पवनसुत सेवा संस्थान के सेवा एवं आध्यात्मिक कार्य।"
            })
            $totalPhotos++
        } else {
            $photoList = @()
            $pIdx = 1
            foreach ($f in $albumFiles) {
                $relPath = "gallery/" + $dir.Name + "/" + $f.Name
                
                $pTitle = "$cleanName - फोटो $pIdx"
                $pDesc = "पवनसुत सेवा संस्थान के पावन कार्य एवं गतिविधियाँ।"

                if ($existingPhotosMap.ContainsKey($relPath)) {
                    $old = $existingPhotosMap[$relPath]
                    if ($old.title -and ($old.title -notmatch "^.* - फोटो \d+$")) { $pTitle = $old.title }
                    if ($old.desc -and ($old.desc -ne "पवनसुत सेवा संस्थान के पावन कार्य एवं गतिविधियाँ।")) { $pDesc = $old.desc }
                }

                $photoList += [PSCustomObject]@{
                    src = $relPath
                    title = $pTitle
                    desc = $pDesc
                }
                $pIdx++
                $totalPhotos++
            }
        }

        $albumDesc = "पवनसुत सेवा संस्थान के सेवा एवं आध्यात्मिक कार्यों की पावन झलक।"
        if ($defaultAlbumInfo.ContainsKey($cleanName)) {
            $albumDesc = $defaultAlbumInfo[$cleanName]
        } elseif ($existingAlbumsMap.ContainsKey($albumId) -and $existingAlbumsMap[$albumId].desc) {
            $albumDesc = $existingAlbumsMap[$albumId].desc
        }

        $albums += [PSCustomObject]@{
            id = $albumId
            title = $cleanName
            desc = $albumDesc
            cover = $photoList[0].src
            photos = $photoList
        }

        Write-Host " ✓ [$cleanName] : $($photoList.Count) फोटो" -ForegroundColor Green
        $dirIndex++
    }
} else {
    # Fallback if no subfolders: scan gallery root
    $rootFiles = Get-ChildItem -Path $folder -File | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object Name
    if ($rootFiles.Count -gt 0) {
        Write-Host " (सीधे gallery फोल्डर की फोटो स्कैन हो रही हैं...)" -ForegroundColor Yellow
        $photoList = @()
        $pIdx = 1
        foreach ($f in $rootFiles) {
            $relPath = "gallery/" + $f.Name
            $photoList += [PSCustomObject]@{
                src = $relPath
                title = "फोटो $pIdx"
                desc = "पवनसुत सेवा संस्थान के सेवा एवं आध्यात्मिक कार्य।"
            }
            $pIdx++
            $totalPhotos++
        }
        $albums += [PSCustomObject]@{
            id = "default_album"
            title = "सेवा और भक्ति की झलकियाँ"
            desc = "पवनसुत सेवा संस्थान के सेवा एवं आध्यात्मिक आयोजनों की पावन झलकियाँ।"
            cover = $photoList[0].src
            photos = $photoList
        }
    }
}

if ($albums.Count -eq 0) {
    Write-Host " गैलरी में कोई फोटो नहीं मिली!" -ForegroundColor Red
    pause
    exit
}

# Generate JavaScript content
$albumsJson = $albums | ConvertTo-Json -Depth 5
$legacyJson = ($albums | ForEach-Object {
    [PSCustomObject]@{
        src = $_.cover
        title = $_.title
        desc = $_.desc
    }
}) | ConvertTo-Json -Depth 3

$outputContent = "// Auto-generated by Update_Gallery.bat - Pawansut Seva Sansthan`r`nwindow.GALLERY_ALBUMS = $albumsJson;`r`n`r`n// Backwards compatibility`r`nwindow.GALLERY_IMAGES = $legacyJson;`r`n"

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($dataPath, $outputContent, $utf8Bom)

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " सफलता! कुल $($albums.Count) एल्बम और $totalPhotos फोटो गैलरी में अपडेट हो चुकी हैं।" -ForegroundColor Green
Write-Host " Success! $dataPath updated with $($albums.Count) albums ($totalPhotos photos)." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "अब वेबसाइट को ब्राउज़र में रिफ्रेश (Refresh / F5) करके देखें।" -ForegroundColor Cyan
Start-Sleep -Seconds 2
