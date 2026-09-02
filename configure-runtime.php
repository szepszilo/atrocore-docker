<?php

declare(strict_types=1);

/**
 * AtroCore Railway runtime configuration.
 *
 * A PostgreSQL kapcsolatot a Railway environment variable-jeiből
 * írja be az AtroCore konfigurációjába minden induláskor.
 */

$appDir = getenv('ATROCORE_APP_DIR') ?: '/var/www/atrocore';

$requiredVariables = [
    'PGHOST',
    'PGPORT',
    'PGDATABASE',
    'PGUSER',
    'PGPASSWORD',
];

foreach ($requiredVariables as $variable) {
    $value = getenv($variable);

    if ($value === false || $value === '') {
        fwrite(
            STDERR,
            sprintf(
                "Missing required environment variable: %s\n",
                $variable
            )
        );

        exit(1);
    }
}

if (!is_dir($appDir)) {
    fwrite(
        STDERR,
        sprintf(
            "AtroCore application directory does not exist: %s\n",
            $appDir
        )
    );

    exit(1);
}

$autoload = $appDir . '/vendor/autoload.php';

if (!is_file($autoload)) {
    fwrite(
        STDERR,
        sprintf(
            "AtroCore autoloader not found: %s\n",
            $autoload
        )
    );

    exit(1);
}

chdir($appDir);
set_include_path($appDir);

require_once $autoload;

try {
    $app = new \Atro\Core\Application();

    $config = $app
        ->getContainer()
        ->get('config');

    $config->set(
        'database',
        [
            'driver'   => 'pdo_pgsql',
            'host'     => getenv('PGHOST'),
            'port'     => getenv('PGPORT'),
            'charset'  => 'utf8',
            'dbname'   => getenv('PGDATABASE'),
            'user'     => getenv('PGUSER'),
            'password' => getenv('PGPASSWORD'),
        ]
    );

    /*
     * Railway/Linux konténerkörnyezetben ez hasznos,
     * ha később Chromium/PDF-generálás kerül használatba.
     */
    $config->set('useChromeNoSandbox', true);

    $config->save();

    echo sprintf(
        "AtroCore database configured: %s:%s/%s\n",
        getenv('PGHOST'),
        getenv('PGPORT'),
        getenv('PGDATABASE')
    );
} catch (\Throwable $exception) {
    fwrite(
        STDERR,
        'Unable to configure AtroCore: '
        . $exception->getMessage()
        . PHP_EOL
    );

    exit(1);
}
