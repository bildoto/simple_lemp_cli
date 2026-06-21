<?php
declare(strict_types=1);

$json = shell_exec('/usr/local/sbin/site-status 2>/dev/null');
$data = json_decode($json ?? '', true);

if (!is_array($data)) {
    http_response_code(500);
    echo 'Could not read server status.';
    exit;
}

function h(string $value): string {
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}

function badge(string $status): string {
    $class = match ($status) {
        'active' => 'ok',
        'inactive' => 'warn',
        'suspended' => 'bad',
        'not_found' => 'bad',
        default => 'warn',
    };

    return '<span class="badge ' . $class . '">' . h($status) . '</span>';
}

$server = $data['server'] ?? [];
$services = $data['services'] ?? [];
$counts = $data['site_counts'] ?? [];
$sites = $data['sites'] ?? [];
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Server Status</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: system-ui, sans-serif;
            background: #f3f4f6;
            color: #111827;
            margin: 0;
            padding: 2rem;
        }

        .wrap {
            max-width: 1000px;
            margin: 0 auto;
        }

        h1 {
            margin-top: 0;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 1rem;
            margin-bottom: 1rem;
        }

        .card {
            background: white;
            border: 1px solid #e5e7eb;
            border-radius: 0.75rem;
            padding: 1rem;
            box-shadow: 0 1px 2px rgba(0,0,0,.04);
        }

        .label {
            color: #6b7280;
            font-size: .85rem;
        }

        .value {
            font-size: 1.4rem;
            font-weight: 700;
            margin-top: .25rem;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 0.75rem;
            overflow: hidden;
            border: 1px solid #e5e7eb;
            margin-bottom: 1rem;
        }

        th, td {
            padding: .75rem 1rem;
            border-bottom: 1px solid #e5e7eb;
            text-align: left;
        }

        th {
            background: #f9fafb;
            color: #374151;
        }

        tr:last-child td {
            border-bottom: 0;
        }

        .badge {
            display: inline-block;
            padding: .2rem .55rem;
            border-radius: 999px;
            font-size: .8rem;
            font-weight: 700;
        }

        .ok {
            background: #dcfce7;
            color: #166534;
        }

        .warn {
            background: #fef3c7;
            color: #92400e;
        }

        .bad {
            background: #fee2e2;
            color: #991b1b;
        }

        .footer {
            color: #6b7280;
            font-size: .85rem;
            margin-top: 1rem;
        }
    </style>
</head>
<body>
<div class="wrap">
    <h1>Server Status</h1>

    <div class="grid">
        <div class="card">
            <div class="label">Hostname</div>
            <div class="value"><?= h((string)($server['hostname'] ?? 'unknown')) ?></div>
        </div>

        <div class="card">
            <div class="label">Uptime</div>
            <div class="value"><?= h((string)($server['uptime'] ?? 'unknown')) ?></div>
        </div>

        <div class="card">
            <div class="label">Load average</div>
            <div class="value"><?= h((string)($server['load_average'] ?? 'unknown')) ?></div>
        </div>

        <div class="card">
            <div class="label">Root disk used</div>
            <div class="value"><?= h((string)($server['disk_root_used'] ?? 'unknown')) ?></div>
        </div>

        <div class="card">
            <div class="label">Memory</div>
            <div class="value">
                <?= h((string)($server['memory_used_mb'] ?? '?')) ?>
                /
                <?= h((string)($server['memory_total_mb'] ?? '?')) ?> MB
            </div>
        </div>

        <div class="card">
            <div class="label">Sites</div>
            <div class="value">
                <?= (int)($counts['active'] ?? 0) ?> active
            </div>
        </div>
    </div>

    <h2>Services</h2>

    <table>
        <thead>
        <tr>
            <th>Service</th>
            <th>Status</th>
        </tr>
        </thead>
        <tbody>
        <?php foreach ($services as $name => $status): ?>
            <tr>
                <td><?= h((string)$name) ?></td>
                <td><?= badge((string)$status) ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>

    <h2>Sites</h2>

    <table>
        <thead>
        <tr>
            <th>Domain</th>
            <th>Status</th>
        </tr>
        </thead>
        <tbody>
        <?php if (empty($sites)): ?>
            <tr>
                <td colspan="2">No sites found.</td>
            </tr>
        <?php else: ?>
            <?php foreach ($sites as $site): ?>
                <tr>
                    <td><?= h((string)($site['domain'] ?? 'unknown')) ?></td>
                    <td><?= badge((string)($site['status'] ?? 'unknown')) ?></td>
                </tr>
            <?php endforeach; ?>
        <?php endif; ?>
        </tbody>
    </table>

    <div class="footer">
        Updated: <?= h(date('Y-m-d H:i:s')) ?>
    </div>
</div>
</body>
</html>
