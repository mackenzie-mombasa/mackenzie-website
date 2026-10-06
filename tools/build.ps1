# Builds the public pages from draft.html (the working draft with the review tools).
# Output: index.html, apartments/, amenities/, marina/, contact/, gardens/ (redirect), 404.html, sitemap.xml, robots.txt
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$site = "https://www.mackenziemombasa.com"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$src  = [IO.File]::ReadAllText("$root\draft.html")
$opt  = [Text.RegularExpressions.RegexOptions]::Singleline

$pages = @(
  @{ key="home";       dir="";            title="Furnished Apartments for Long-Term Rent in Nyali, Mombasa | Mackenzie Apartments"; desc="Furnished waterfront apartments for long-term rent in tropical gardens on Tudor Creek, by Nyali Bridge, Mombasa. A private gated community with two pools, a gym and a jetty." },
  @{ key="apartments"; dir="apartments/"; title="Studio, 1, 2 and 3 Bedroom Furnished Apartments in Mombasa | Mackenzie Apartments";       desc="Studio, one, two and three-bedroom furnished apartments for long-term rent in Nyali, Mombasa. All en-suite, with air conditioning, equipped kitchens, Wi-Fi and garden or creek views." },
  @{ key="living";     dir="amenities/";  title="Pools, Gym, Jetty and 24-Hour Security | Mackenzie Apartments Mombasa";                    desc="Two swimming pools, a residents' gym, decks on the water, a private jetty, tropical gardens, covered parking and 24-hour security at Mackenzie Apartments, Mombasa." },
  @{ key="marina";     dir="marina/";     title="Private Jetty and Boat Moorings on Tudor Creek, Mombasa | Mackenzie Apartments";            desc="A private jetty and pontoon moorings for boats up to 30 ft on a sheltered stretch of Tudor Creek, Mombasa. For residents and visiting boat owners." },
  @{ key="contact";    dir="contact/";    title="Contact and Viewings | Mackenzie Apartments Mombasa";                                       desc="Contact Mackenzie Apartments Mombasa on WhatsApp +254 700 932 020 or by email to arrange a viewing. Ras Kisauni Road, by Nyali Bridge, Mombasa." }
)
$route = @{ home=""; apartments="apartments/"; living="amenities/"; gardens="amenities/"; marina="marina/"; contact="contact/"; location="#nearby"; faq="contact/#faq" }

# split the page blocks out of the draft
$blocks = @{}
foreach($m in [regex]::Matches($src,'<div class="page" data-page="(\w+)"[^>]*>.*?(?=\s*(?:<!--[^>]*-->\s*)?<div class="page" data-page=|\s*</main>)',$opt)){ $blocks[$m.Groups[1].Value] = $m.Value }
$mainStart = $src.IndexOf('<main>') + 6; $mainEnd = $src.IndexOf('</main>')
$before = $src.Substring(0,$mainStart); $after = $src.Substring($mainEnd)

foreach($pg in $pages){
  $p = if($pg.dir){ "../" } else { "" }
  $homeHref = if($pg.dir){ "../" } else { "./" }
  $block = [regex]::Replace($blocks[$pg.key],'^(<div class="page" data-page="\w+")\s+hidden','$1')
  $html = $before + "`n  " + $block + "`n  " + $after

  # head
  $html = $html.Replace('<html lang="en">','<html lang="en" data-launch="1">')
  $html = [regex]::Replace($html,'<title>.*?</title>',{ param($x) "<title>$($pg.title)</title>" },$opt)
  $html = [regex]::Replace($html,'<meta name="description" content="[^"]*">',{ param($x) '<meta name="description" content="'+$pg.desc+'">' })
  $html = [regex]::Replace($html,'<link rel="canonical" href="[^"]*">',{ param($x) '<link rel="canonical" href="'+$site+'/'+$pg.dir+'">' })
  $html = [regex]::Replace($html,'<meta property="og:url" content="[^"]*">',{ param($x) '<meta property="og:url" content="'+$site+'/'+$pg.dir+'">' })
  # public pages are open to search engines (draft.html keeps its noindex)
  $html = [regex]::Replace($html,'<meta name="robots" content="noindex, nofollow">\r?\n?','')
  $html = $html.Replace('href="fonts/fonts.css"','href="'+$p+'fonts/fonts.css"')
  $html = $html.Replace('</head>','<link rel="icon" href="/favicon.ico" sizes="48x48">'+"`n"+'<link rel="icon" href="/favicon.svg" type="image/svg+xml">'+"`n"+'<link rel="icon" href="/favicon-192.png" type="image/png" sizes="192x192">'+"`n"+'<link rel="apple-touch-icon" href="/apple-touch-icon.png">'+"`n"+'<style>body{background:var(--paper)}</style>'+"`n"+'</head>')

  # remove the review tools
  $a = $html.IndexOf('<div class="draftbar">'); $b = $html.IndexOf('<div class="stage"')
  if($a -ge 0 -and $b -gt $a){ $html = $html.Remove($a,$b-$a) }
  $html = [regex]::Replace($html,'\s*var PICK = \[.*?\];','',$opt)
  $html = [regex]::Replace($html,'\s*var pickEl = .*?\n','' + "`n")
  $html = [regex]::Replace($html,'\s*var SH = "";.*?\n',"`n")

  # real links
  $html = [regex]::Replace($html,'href="#(home|apartments|living|gardens|marina|contact|location|faq)"',{ param($x)
    $k = $x.Groups[1].Value; $t = $route[$k]
    if($k -eq "home"){ return 'href="'+$homeHref+'"' }
    if($t.StartsWith("#")){ if($pg.key -eq "home"){ return 'href="'+$t+'"' } else { return 'href="../'+$t+'"' } }
    if($t -eq $pg.dir){ return 'href="./" aria-current="page"' }
    return 'href="'+$p+$t+'"'
  })
  if($pg.key -eq "home"){ $html = $html.Replace('<a href="./">Home</a>','<a href="./" aria-current="page">Home</a>') }

  # asset paths for pages one folder down
  if($p){ $html = [regex]::Replace($html,'(?<=["''(])img/',$p+'img/') }

  $outDir = Join-Path $root $pg.dir; if($pg.dir){ New-Item -ItemType Directory -Force $outDir | Out-Null }
  [IO.File]::WriteAllText((Join-Path $outDir "index.html"),$html,$utf8)
  "{0,-12} {1,4} KB  photos {2}" -f ($pg.dir + "index.html"),[int]($html.Length/1kb),([regex]::Matches($html,'<img ')).Count
}

# old /gardens address -> amenities
New-Item -ItemType Directory -Force "$root\gardens" | Out-Null
[IO.File]::WriteAllText("$root\gardens\index.html",'<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Pools and gardens | Mackenzie Apartments Mombasa</title><link rel="canonical" href="'+$site+'/amenities/"><meta http-equiv="refresh" content="0; url=../amenities/"></head><body><p><a href="../amenities/">Pools, gardens and amenities</a></p></body></html>',$utf8)

[IO.File]::WriteAllText("$root\404.html",'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex"><title>Page not found | Mackenzie Apartments Mombasa</title><style>body{margin:0;font:18px/1.6 Georgia,serif;background:#F6F7F3;color:#16201E;display:grid;place-items:center;min-height:100vh;padding:24px;text-align:center}h1{font:800 40px/1.1 system-ui,sans-serif;margin:0 0 12px}a{color:#16201E;font-weight:600;text-decoration-color:#B8306F;text-decoration-thickness:2px;text-underline-offset:4px}</style></head><body><div><h1>That page has moved</h1><p>The address you followed is no longer here.</p><p><a href="/">Go to the Mackenzie Apartments homepage</a></p></div></body></html>',$utf8)

[IO.File]::WriteAllText("$root\favicon.svg",'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#1B4F55"/><path d="M14 46V18h7l11 17 11-17h7v28h-7V30L32 45 21 30v16z" fill="#F6F7F3"/></svg>',$utf8)

$today = (Get-Date).ToString("yyyy-MM-dd")
$urls = ($pages | ForEach-Object { "  <url><loc>$site/$($_.dir)</loc><lastmod>$today</lastmod></url>" }) -join "`n"
[IO.File]::WriteAllText("$root\sitemap.xml","<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n$urls`n</urlset>`n",$utf8)
[IO.File]::WriteAllText("$root\robots.txt","User-agent: *`nAllow: /`nDisallow: /tools/`n`nSitemap: $site/sitemap.xml`n",$utf8)
"built: gardens redirect, 404, favicon, sitemap, robots"
