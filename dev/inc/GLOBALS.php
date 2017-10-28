<?php
// Contains all of the constants for the code that can't be stored in the database

// Database credentials
define('DB_DYSTRACK_HOST', 'localhost');
define('DB_DYSTRACK_PORT', 3306);
define('DB_DYSTRACK_NAME', 'dystify_dystrack_server');
define('DB_DYSTRACK_USER', 'dystify_dev');
define('DB_DYSTRACK_PASS', 'foobarbaz3001');

// OAUTH2 credentials
define('OAUTH2_CLIENT_ID', '158589866683-gs7s9cvck0t59ld66an2aidcr9su9g0i.apps.googleusercontent.com');
define('OAUTH2_CLIENT_SECRET', '51ltuLODBhXM7a7ryncnRDVu');
define('OAUTH2_CALLBACK', 'https://dystify.com/kkdystrack/php/login_callback.php');
define('OAUTH2_AUTH', $_SERVER['DOCUMENT_ROOT'] . '/ext-api/client-secret.json');
define('YOUTUBE_DATA_API_KEY', 'AIzaSyAM47hrLonwkbEKQ0poD8VU3E7mlpLGVxQ');

// Other stuff
define('IFTTT_KEY', '364980796a286a1643dd384994d73757c5fa650d11aba0a49b7062c5e0553c2bc49170b26f7eb94681261e286f83ed808a6be8476cad38a7612003fdbbf02b92');
?>