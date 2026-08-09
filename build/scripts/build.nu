use lib/common.nu [resolve-project-root load-config]
use lib/repos.nu [run-repo-stage]
use lib/packages.nu [install-package-groups install-package-group finalize-packages]
use lib/system.nu [run-system-stage]

export def main [
  build_root?: string
  --dry-run(-n)
  --stage: string = "all"   # repo | packages | finalize | system | all
  --group: string = ""      # single package group to install (with --stage packages)
] {
  let root = if ($build_root | is-not-empty) {
    $build_root
  } else {
    resolve-project-root
  }

  let cfg = load-config $root

  print $"==> using build root: ($root)"
  if $dry_run {
    print "==> mode: dry-run"
  }
  print $"==> stage: ($stage)"

  let all = ($stage == "all")
  let do_repo = ($stage == "repo" or $all)
  let do_packages = ($stage == "packages" or $all)
  let do_finalize = ($stage == "finalize" or $all)
  let do_system = ($stage == "system" or $all)

  if $do_repo {
    run-repo-stage $dry_run $cfg.repos
  }

  if $do_packages {
    if ($group | is-not-empty) {
      install-package-group $dry_run $cfg.packages $group
    } else {
      install-package-groups $dry_run $cfg.packages
    }
  }

  if $do_finalize {
    finalize-packages $dry_run $cfg.packages $cfg.extras
  }

  if $do_system {
    run-system-stage $dry_run $cfg.system
  }
}
