# Rakefile
desc 'Install Krage'
task default: [:install]

task :configure do
  puts 'Configuring...'
  home = `echo -n $HOME`
  @krage_dir = File.expand_path("#{File.dirname(__FILE__)}")
  @app_icon_dir = "#{home}/.local/share/icons/"
  @app_desktop_dir = "#{home}/.local/share/applications/"
  chmod 0755, "#{@krage_dir}/bin/krage"
  `chmod 755 #{@krage_dir}/ext/gen*`
end

task :clean => [:configure] do
  puts 'Cleaning...'
  old_krage_chk = `readlink -fn /usr/local/games/krage`.sub(/\/bin\/krage/, '')
  if old_krage_chk != '/usr/local/games/krage' && @krage_dir != old_krage_chk
    Dir.chdir(old_krage_chk) do
      system('rake uninstall')
    end
    next
  end
  `sudo rm -f /usr/local/games/krage`
  rm_f("#{@app_desktop_dir}krage.desktop")
  rm_f("#{@app_icon_dir}krage_crow.png")
  unless `dconf dump /org/gnome/terminal/legacy/profiles:/ | grep 'krage'`.empty?
    krage_profile_id = File.read("#{@krage_dir}/ext/.current_krage_id")

    `dconf reset -f /org/gnome/terminal/legacy/profiles:/:#{krage_profile_id}/`

    user_profile = `dconf dump /org/gnome/terminal/legacy/profiles:/`
    user_profile.gsub!(/(, )?'#{krage_profile_id}'(, )?/, '\2')

    `echo -n "#{user_profile}" > #{@krage_dir}/ext/.user_profile.dconf`

    `dconf load /org/gnome/terminal/legacy/profiles:/ < #{@krage_dir}/ext/.user_profile.dconf`
    `rm #{@krage_dir}/ext/.??*`
  end
end

desc 'Uninstall Krage'
task :uninstall => [:clean] do
  puts 'Uninstalling Krage...'
  rm_rf(@krage_dir)
end

task :install => [:clean] do
  puts 'Installing Krage...'
  `sudo ln -s #{@krage_dir}/bin/krage '/usr/local/games'`
  mkdir_p @app_icon_dir
  ln_s("#{@krage_dir}/data/krage_crow.png", @app_icon_dir)
  ln_s("#{@krage_dir}/ext/krage.desktop", @app_desktop_dir)
end
