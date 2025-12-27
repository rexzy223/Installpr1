#!/bin/bash

BASE="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Memasang proteksi Anti Akses Nest & Egg..."

mkdir -p "$BASE"
chmod 755 "$BASE"

# ===================== NestController =====================
NEST_PATH="$BASE/NestController.php"
NEST_BACKUP="${NEST_PATH}.bak_${TIMESTAMP}"

if [ -f "$NEST_PATH" ]; then
  mv "$NEST_PATH" "$NEST_BACKUP"
  echo "📦 Backup NestController: $NEST_BACKUP"
fi

cat > "$NEST_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nests;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Nests\NestUpdateService;
use Pterodactyl\Services\Nests\NestCreationService;
use Pterodactyl\Services\Nests\NestDeletionService;
use Pterodactyl\Contracts\Repository\NestRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Nest\StoreNestFormRequest;
use Illuminate\Support\Facades\Auth;

class NestController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected NestCreationService $nestCreationService,
        protected NestDeletionService $nestDeletionService,
        protected NestRepositoryInterface $repository,
        protected NestUpdateService $nestUpdateService,
        protected ViewFactory $view
    ) {}

    public function index(): View
    {
        $user = Auth::user();
        if (!$user || (int) $user->id !== 1) {
            abort(403, '🚫 Akses Nest hanya untuk Admin ID 1');
        }

        return $this->view->make('admin.nests.index', [
            'nests' => $this->repository->getWithCounts(),
        ]);
    }

    public function create(): View
    {
        return $this->view->make('admin.nests.new');
    }

    public function store(StoreNestFormRequest $request): RedirectResponse
    {
        $nest = $this->nestCreationService->handle($request->normalize());
        $this->alert->success(trans('admin/nests.notices.created'))->flash();

        return redirect()->route('admin.nests.view', $nest->id);
    }

    public function view(int $nest): View
    {
        return $this->view->make('admin.nests.view', [
            'nest' => $this->repository->getWithEggServers($nest),
        ]);
    }

    public function update(StoreNestFormRequest $request, int $nest): RedirectResponse
    {
        $this->nestUpdateService->handle($nest, $request->normalize());
        $this->alert->success(trans('admin/nests.notices.updated'))->flash();

        return redirect()->route('admin.nests.view', $nest);
    }

    public function destroy(int $nest): RedirectResponse
    {
        $this->nestDeletionService->handle($nest);
        $this->alert->success(trans('admin/nests.notices.deleted'))->flash();

        return redirect()->route('admin.nests');
    }
}
EOF

# ===================== EggController =====================
EGG_PATH="$BASE/EggController.php"
EGG_BACKUP="${EGG_PATH}.bak_${TIMESTAMP}"

if [ -f "$EGG_PATH" ]; then
  mv "$EGG_PATH" "$EGG_BACKUP"
  echo "📦 Backup EggController: $EGG_BACKUP"
fi

cat > "$EGG_PATH" << 'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nests;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\Factory as ViewFactory;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Eggs\EggUpdateService;
use Pterodactyl\Services\Eggs\EggCreationService;
use Pterodactyl\Services\Eggs\EggDeletionService;
use Pterodactyl\Contracts\Repository\EggRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Egg\StoreEggFormRequest;

class EggController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected EggCreationService $eggCreationService,
        protected EggDeletionService $eggDeletionService,
        protected EggRepositoryInterface $repository,
        protected EggUpdateService $eggUpdateService,
        protected ViewFactory $view
    ) {
        $this->middleware(function ($request, $next) {
            $user = Auth::user();
            if (!$user || (int) $user->id !== 1) {
                abort(403, '🚫 Akses Egg hanya untuk Admin ID 1');
            }
            return $next($request);
        });
    }

    public function view(int $nest, int $egg): View
    {
        return $this->view->make('admin.nests.eggs.view', [
            'egg' => $this->repository->getWithCopyVariables($egg),
            'nest' => $nest,
        ]);
    }

    public function update(StoreEggFormRequest $request, int $nest, int $egg): RedirectResponse
    {
        $this->eggUpdateService->handle($egg, $request->normalize());
        $this->alert->success(trans('admin/eggs.notices.updated'))->flash();

        return redirect()->route('admin.nests.eggs.view', [$nest, $egg]);
    }

    public function destroy(int $nest, int $egg): RedirectResponse
    {
        $this->eggDeletionService->handle($egg);
        $this->alert->success(trans('admin/eggs.notices.deleted'))->flash();

        return redirect()->route('admin.nests.view', $nest);
    }
}
EOF

chmod 644 "$NEST_PATH" "$EGG_PATH"

echo "✅ Proteksi Anti Akses Nest & Egg berhasil dipasang"
echo "🔒 Hanya Admin ID 1 yang dapat mengakses Nest & Egg"