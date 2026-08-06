use common.nu [print-step print-bullets run-cmd dnf-clean dnf-install-lean strip-version-prefix]

def extract-font-archive [dry_run: bool, archive: string, dest: string] {
  if ($archive | str ends-with ".zip") {
    run-cmd $dry_run "unzip" ["-q" "-o" $archive "-d" $dest]
  } else if ($archive | str ends-with ".tar.gz") or ($archive | str ends-with ".tgz") {
    run-cmd $dry_run "tar" ["-xzf" $archive "-C" $dest]
  } else if ($archive | str ends-with ".tar.xz") {
    run-cmd $dry_run "tar" ["-xJf" $archive "-C" $dest]
  } else if ($archive | str ends-with ".tar.bz2") {
    run-cmd $dry_run "tar" ["-xjf" $archive "-C" $dest]
  } else if ($archive | str ends-with ".tar") {
    run-cmd $dry_run "tar" ["-xf" $archive "-C" $dest]
  } else if ($archive | str ends-with ".7z") {
    run-cmd $dry_run "7z" ["x" "-y" $"-o($dest)" $archive]
  } else {
    # plain font file
    run-cmd $dry_run "cp" [$archive $"($dest)/($archive | path basename)"]
  }
}

export def install-fonts [dry_run: bool, fonts] {
  if (($fonts | length) == 0) {
    return
  }

  print-step "installing fonts"

  for font in $fonts {
    let name = $font.name
    let url = $font.url
    let dest = $font.dest_dir
    let filename = ($url | path basename)

    print $"  - ($name)"
    print $"    url: ($url)"
    print $"    dest: ($dest)"

    if $dry_run {
      print $"    note: download + extract skipped in dry-run"
      continue
    }

    let tmp = $"/tmp/($name | str kebab-case)"
    run-cmd false "mkdir" ["-p" $tmp $dest]
    run-cmd false "curl" ["-L" "--fail" "--silent" "--show-error" "-o" $"($tmp)/($filename)" $url]
    extract-font-archive false $"($tmp)/($filename)" $dest
    run-cmd false "rm" ["-rf" $tmp]
  }
}

export def install-package-groups [dry_run: bool, packages_cfg] {
  for group in $packages_cfg.install_order {
    let packages = ($packages_cfg.groups | get $group)
    print-step $"installing package group: ($group)"
    dnf-install-lean $dry_run $packages
  }
}

export def remove-packages [dry_run: bool, packages] {
  if (($packages | length) == 0) {
    return
  }

  print-step "removing packages"
  print-bullets $packages
  run-cmd $dry_run "dnf" (["remove" "-y"] | append $packages)
}

export def install-static-rpms [dry_run: bool, rpms] {
  print-step "installing static rpm urls"

  for rpm in $rpms {
    print $"  - ($rpm.name)"
    print $"    url: ($rpm.url)"
    run-cmd $dry_run "dnf" ["install" "-y" $rpm.url]
  }
}

export def install-github-latest-rpms [dry_run: bool, rpms] {
  print-step "installing github latest rpms"

  for rpm in $rpms {
    if $dry_run {
      print $"  - ($rpm.name)"
      print $"    repo: ($rpm.repo)"
      print $"    url-template: ($rpm.url_template)"
      print $"    note: latest tag lookup skipped in dry-run"
    } else {
      let release = (http get $"https://api.github.com/repos/($rpm.repo)/releases/latest")
      let tag = ($release | get tag_name | str trim)
      let version = (strip-version-prefix $tag $rpm.version_prefix_to_strip)
      let url = ($rpm.url_template | str replace "{tag}" $tag | str replace "{version}" $version)

      print $"  - ($rpm.name)"
      print $"    tag: ($tag)"
      print $"    url: ($url)"
      run-cmd false "dnf" ["install" "-y" $url]
    }
  }
}

export def reinstall-packages [dry_run: bool, packages] {
  if (($packages | length) == 0) {
    return
  }

  print-step "reinstalling packages (remove then install)"
  print-bullets $packages
  run-cmd $dry_run "dnf" (["remove" "-y"] | append $packages)
  run-cmd $dry_run "dnf" ["install" "-y" "--setopt=install_weak_deps=False" "--nodocs" ...$packages]
}

export def run-package-stage [dry_run: bool, packages_cfg, extras_cfg] {
  install-package-groups $dry_run $packages_cfg
  remove-packages $dry_run $packages_cfg.remove
  reinstall-packages $dry_run $packages_cfg.reinstall
  install-static-rpms $dry_run $extras_cfg.static
  install-github-latest-rpms $dry_run $extras_cfg.github_latest
  install-fonts $dry_run $extras_cfg.fonts
  dnf-clean $dry_run
}
