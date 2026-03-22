<?php
/**
 * HTML cleaning proxy for VBXE Browser (Atari 8-bit)
 * Strips scripts, styles, SVG, and unnecessary attributes.
 *
 * Usage: http://turiecfoto.sk/proxy.php?url=aktuality.sk
 * Atari: N:http://turiecfoto.sk/proxy.php?url=aktuality.sk
 */

// Get URL parameter
$url = $_GET['url'] ?? '';
if (!$url) {
    header('Content-Type: text/html; charset=utf-8');
    echo '<html><body><h1>VBXE Browser Proxy</h1>';
    echo '<p>Usage: ?url=example.com</p></body></html>';
    exit;
}

// Add http:// if missing
if (!preg_match('#^https?://#i', $url)) {
    $url = 'http://' . $url;
}

// Fetch the page
$ctx = stream_context_create([
    'http' => [
        'header' => "User-Agent: Mozilla/5.0 (compatible; VBXEBrowser/1.0)\r\n" .
                     "Accept: text/html,*/*\r\n" .
                     "Accept-Language: sk,en;q=0.5\r\n",
        'timeout' => 15,
        'follow_location' => true,
        'max_redirects' => 5,
    ],
    'ssl' => [
        'verify_peer' => false,
        'verify_peer_name' => false,
    ],
]);

$html = @file_get_contents($url, false, $ctx);
if ($html === false) {
    header('Content-Type: text/html; charset=utf-8');
    echo '<html><body><h1>Error</h1><p>Cannot fetch: ' . htmlspecialchars($url) . '</p></body></html>';
    exit;
}

// Detect and convert encoding to UTF-8
if (preg_match('/charset=(["\']?)([^"\'\s;>]+)/i', $html, $m)) {
    $charset = strtolower($m[2]);
} else {
    $charset = 'utf-8';
}
if ($charset !== 'utf-8') {
    $html = @mb_convert_encoding($html, 'UTF-8', $charset) ?: $html;
}

// Strip junk
$html = preg_replace('/<!--.*?-->/s', '', $html);           // comments
$html = preg_replace('/<script[\s>].*?<\/script>/si', '', $html);  // scripts
$html = preg_replace('/<style[\s>].*?<\/style>/si', '', $html);    // styles
$html = preg_replace('/<svg[\s>].*?<\/svg>/si', '', $html);        // SVG
$html = preg_replace('/<noscript[^>]*>/i', '', $html);       // unwrap noscript
$html = preg_replace('/<\/noscript>/i', '', $html);

// Strip unnecessary attributes (keep href, src, alt)
$html = preg_replace(
    '/\s+(?:class|style|data-[\w-]+|onclick|onload|onmouseover|'
    . 'aria-[\w-]+|role|tabindex|target|rel|loading|decoding|'
    . 'srcset|sizes|width|height|id)='
    . '(?:"[^"]*"|\'[^\']*\'|\S+)/i',
    '', $html
);

// Collapse whitespace
$html = preg_replace('/[ \t]+/', ' ', $html);
$html = preg_replace('/\n{3,}/', "\n\n", $html);
$html = trim($html);

// Output
header('Content-Type: text/html; charset=utf-8');
echo $html;
