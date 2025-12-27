#!/bin/bash

BASE="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes"
REMOTE_PATH="$BASE/NodeController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
TS=$(date +%s)

echo "🚀 Memasang proteksi Anti Akses Nodes..."

mkdir -p "$BASE"
chmod 755 "$BASE"

# ================= BACKUP NodeController =================
if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "📦 Backup file lama dibuat di $BACKUP_PATH"
fi

# ================= TRAIT GUARD =================
cat > "$BASE/NodeAccessGuard.php" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\Support\Facades\Auth;

trait NodeAccessGuard
{
    protected function onlySuperAdmin(): void
    {
        $user = Auth::user();
        if (!$user || (int) $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang dapat membuka menu Nodes.');
        }
    }
}
EOF

# ================= NodeController =================
cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Spatie\QueryBuilder\QueryBuilder;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Illuminate\Support\Facades\Auth;

class NodeController extends Controller
{
    public function __construct(private ViewFactory $view)
    {
    }

    public function index(Request $request): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang dapat membuka menu Nodes.');
        }

        $nodes = QueryBuilder::for(
            Node::query()->with('location')->withCount('servers')
        )
            ->allowedFilters(['uuid', 'name'])
            ->allowedSorts(['id'])
            ->paginate(25);

        return $this->view->make('admin.nodes.index', ['nodes' => $nodes]);
    }
}
EOF

# ================= NodeViewController =================
mv "$BASE/NodeViewController.php" "$BASE/NodeViewController.php.bak_$TS" 2>/dev/null

cat > "$BASE/NodeViewController.php" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Pterodactyl\Models\Node;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Admin\Nodes\NodeAccessGuard;

class NodeViewController extends Controller
{
    use NodeAccessGuard;

    public function __construct(private ViewFactory $view) {}

    public function index(Node $node): View
    {
        $this->onlySuperAdmin();

        return $this->view->make('admin.nodes.view.index', [
            'node' => $node
        ]);
    }
}
EOF

chmod 644 "$BASE/NodeAccessGuard.php" "$BASE/NodeViewController.php" "$REMOTE_PATH"

echo "✅ Proteksi Anti Akses Nodes berhasil dipasang!"
echo "📂 File: $REMOTE_PATH"
echo "🗂️ Backup: $BACKUP_PATH"
echo "🔒 Hanya Admin ID 1 yang bisa akses Nodes"