module Statue
  class Post
    attr_reader :markdown_file

    def initialize(markdown_file)
      @markdown_file = markdown_file
    end

    extend Forwardable
    def_delegators :frontmatter,
      *%i(title category disqus_id draft? main_image)

    def_delegator :markdown_file, :modified_since?

    def machine_name
      basename.partition('_').last
    end

    def path
      Pathname.new("blog") / category.machine_name / machine_name / 'index.html'
    end

    def uri
      "/#{path.dirname}/"
    end

    def url
      "#{BASE_URL}#{uri}"
    end

    def basename
      markdown_file.path.basename.sub_ext('').to_s
    end

    def date
      Date.iso8601(basename.partition('_').first)
    end

    def frontmatter
      @frontmatter ||= Frontmatter.from_edn(loaded.first)
    end

    def content
      loaded.last
    end

    def html
      @html ||= Markdown.to_html(content)
    end

    def preview_html
      more_separator = '<!--more-->'
      @preview_html ||=
        if html.include?(more_separator)
          html.partition(more_separator).first
        else
          html
        end
    end

    def <=>(other)
      # most recent to oldest
      -(date <=> other.date)
    end

    private

      def loaded
        @loaded ||= EDN.split_frontmatter(markdown_file.read)
      rescue => ex
        raise "Failed to load #{markdown_file.path}: #{ex}"
      end

      class Artist
        value_semantics do
          name String
          url String
        end
      end

      class MainImage
        value_semantics do
          uri Pathname, coerce: PathnameCoercer
          artist Either(Artist, nil), coerce: true, default: nil
        end

        def self.coerce_artist(obj)
          if obj
            Artist.coercer.(obj)
          else
            obj
          end
        end
      end

      class Frontmatter
        value_semantics do
          title String
          disqus_id String
          category Category, coerce: true
          draft? Bool()
          main_image Either(MainImage, nil), coerce: true, default: nil
        end

        def self.coerce_category(obj)
          if obj.is_a?(String)
            Category.lookup(obj) || obj
          else
            obj
          end
        end

        def self.coerce_main_image(obj)
          if obj
            MainImage.coercer.(obj)
          else
            obj
          end
        end

        def self.from_edn(edn)
          new(
            title: edn.fetch(:title),
            disqus_id: edn.fetch(:'disqus-id'),
            category: edn.fetch(:category).to_s,
            draft?: edn.fetch(:draft, false),
            main_image: edn.fetch(:'main-image', nil),
          )
        end
      end

  end
end
