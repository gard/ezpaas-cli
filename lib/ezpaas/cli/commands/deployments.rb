require 'thor'
require 'git'
require 'tmpdir'
require 'tty'
require 'uri'
require 'ezpaas/cli/commands/server_commands'
require 'ezpaas/http/sse_client'

module EzPaaS
  module CLI
    module Commands
      class Deployments < ServerCommands

        desc 'push <app name>', 'Pushes the current git repository'
        option :app, :type => :string, :required => true
        option :dir, :type => :string, :default => Dir.pwd
        option :branch, :type => :string, :default => 'master'
        def push
          pastel = Pastel.new

          app = options[:app]
          dir = options[:dir]
          branch = options[:branch]

          puts 'Opening git repository at ' + pastel.blue(dir)
          git = Git.open(dir)
          branch = git.branches[branch]

          begin
            path = Dir::Tmpname.create('ezpaas') do |file|
              puts 'Archiving ' + pastel.blue(branch) + ' branch'
              branch.archive(file, {format: 'tar'})
            end

            url_str = URI::join(options[:server], "proxy/#{app}/").to_s
            success_msg = pastel.green('Application deployment completed')
            success_msg += "\n" + 'Access your application at ' + pastel.blue(url_str)

            server_comm_wrap(success_msg) do
              sse_client.deploy(app, path) do |message|
                puts message
              end
            end

          ensure
            File.delete(path)
          end
        end

        desc 'destroy', 'Scales all processes of an EzPaas app to zero'
        def destroy(app)
          puts hey
        end

        desc 'scale <app> [<process=count>...]', 'Scales the processes of an EzPaas app'
        def scale(app, *scales)
          puts 'hey'
          puts scales
        end

        private

        no_commands do
          def sse_client
            HTTP::SSEClient.new(options[:server])
          end

          def server_comm_wrap(end_msg)
            screen = TTY::Screen.new
            msg = 'Opening connection to slug compilation container'
            puts msg
            puts '─' * [msg.length, screen.width].min
            puts
            yield
            puts
            puts '─' * [end_msg.length, screen.width].min
            puts end_msg
          end
        end


      end
    end
  end
end
