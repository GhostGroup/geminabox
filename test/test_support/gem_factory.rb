class GemFactory
  class << self
    def fixture_path
      File.join(Dir.tmpdir, "geminabox-fixtures")
    end

    def gem_file(*args)
      new(fixture_path).gem(*args)
    end

    def delete(gemfile)
      FileUtils.rm(File.join(fixture_path, gemfile))
    end
  end

  def initialize(path)
    @path = Pathname.new(File.expand_path(path))
  end

  def gem(name, options = {})
    version  = options[:version] || "1.0.0"
    platform = options[:platform] || "ruby"

    dependencies = options.fetch(:deps, {}).collect do |dep, requirement|
      dep = [*dep]
      gem(*dep)
      if requirement
        "s.add_dependency(#{dep.first.to_s.inspect}, #{requirement.inspect})"
      else
        "s.add_dependency(#{dep.first.to_s.inspect})"
      end
    end.join("\n")

    required_ruby_version = options[:required_ruby_version]
    required_rubygems_version = options[:required_rubygems_version]

    name = name.to_s
    filename = %W[#{name} #{version}]
    filename.push(platform) if platform != "ruby"
    path = @path.join("#{filename.join("-")}.gem")
    FileUtils.mkdir_p File.dirname(path)

    unless File.exist? path
      spec = %{
        Gem::Specification.new do |s|
          s.name                      = #{name.inspect}
          s.version                   = #{version.inspect}
          s.platform                  = #{platform.inspect}
          s.summary                   = #{name.inspect}
          s.description               = s.summary + " description"
          s.author                    = 'Test'
          s.files                     = []
          s.email                     = 'fake@fake.fake'
          s.homepage                  = 'http://fake.fake/fake'
          s.required_ruby_version     = #{required_ruby_version.inspect}
          s.required_rubygems_version = #{required_rubygems_version.inspect}
          #{dependencies}
        end
      }

      Tempfile.open("spec") do |tmpfile|
        tmpfile << spec
        tmpfile.close

        Dir.chdir File.dirname(path) do
          system "gem build --silent #{tmpfile.path}"
        end
      end

      raise "Failed to build gem #{name}" unless File.exist? path
    end
    path
  end

end
