module Git
  class Repo
    class NoRevision < Git::Exception
      def initialize(repo, rev_spec)
        super "No revision: #{rev_spec} in #{repo.path}"
      end
    end

    @safe : Safe::Repository

    private def initialize(@safe : Safe::Repository)
    end

    def self.from_path(path)
      Safe.call :repository_open, out unsafe, path
      new(Safe::Repository.safe(unsafe))
    end

    @path : String?
    def path
      @path ||= Safe.string(:repository_path, @safe)
    end

    @remotes : Hash(String, Remote)?
    def remotes
      @remotes ||= ({} of String => Remote).tap do |h|
        a = C::Strarray.new
        Safe.call :remote_list, pointerof(a), @safe
        Safe::Strarray.safe(a).each do |name|
          h[name] = lookup_remote(name).not_nil!
        end
      end
    end

    def lookup_remote(name)
      Safe.call :remote_lookup, out remote, @safe, name do |call|
        if call.success?
          Remote.new(self, Safe::Remote.safe(remote), name)
        elsif call.result == C::Enotfound
          nil
        else
          call.raise!
        end
      end
    end

    def parse_rev(spec)
      Safe.call :revparse_single, out obj, @safe, spec do |call|
        if call.success?
          Object.new(self, Safe::Object.safe(obj))
        elsif call.result == C::Enotfound
          nil
        else
          call.raise!
        end
      end
    end

    def lookup_ref(name)
      Safe.call :reference_dwim, out ref, @safe, name do |call|
        if call.success?
          Ref.new(self, Safe::Reference.safe(ref))
        elsif call.result == C::Enotfound
          nil
        else
          call.raise!
        end
      end
    end

    def set_head(refname)
      Safe.call :repository_set_head, @safe, refname
    end

    def create_ref(name, oid)
      Safe.call :reference_create, out ref, @safe, name, oid.safe.p, 0, Util.null_pstr do |call|
        if call.success?
          Ref.new(self, Safe::Reference.safe(ref))
        elsif call.result == C::Eexists
          lookup_ref(name).not_nil!
        else
          call.raise!
        end
      end
    end

    def ref_name_to_oid(name)
      Safe.call :reference_name_to_id, out oid, @safe, name do |call|
        if call.success?
          Oid.new(self, Safe::Oid.safe(oid))
        elsif call.result == C::Enotfound
          nil
        else
          call.raise!
        end
      end
    end

    # def checkout_tree(treeish, options = nil)
    #   options ||= begin
    #     opts = CheckoutOptions.init
    #     opts.checkout_strategy = C::CheckoutSafe
    #     opts
    #   end
    #   Safe.call :checkout_tree, self, treeish, options.p
    # end
  end
end
