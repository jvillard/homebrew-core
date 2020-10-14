class Infer < Formula
  desc "Static analyzer for Java, C, C++, and Objective-C"
  homepage "https://fbinfer.com/"
  url "https://github.com/facebook/infer/archive/v1.0.0.tar.gz"
  sha256 "10edee4a37f985afca120337130f92fec67c8651425571987ca2645b937c6395"
  license "MIT"
  head "https://github.com/facebook/infer.git"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    cellar :any
    rebuild 1
    sha256 "1dc9c75c759611c8fe0efa8f63d7e55bbaa35d8dc2863f7a527069b11759f244" => :catalina
    sha256 "74b2dddff2bea362066395e28a797078d33514774511cc64771d0f89eea2466d" => :mojave
    sha256 "7630571f8e391ce0ba991ffe7a5d7b2b4a1029cda1d56497800d8ae0a260d4b6" => :high_sierra
  end

  deprecate! because: :does_not_build

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "libtool" => :build
  depends_on "opam" => :build
  depends_on "openjdk@8" => [:build, :test]
  depends_on "pkg-config" => :build
  depends_on "gmp"
  depends_on "mpfr"
  depends_on "sqlite"

  uses_from_macos "m4" => :build
  uses_from_macos "unzip" => :build
  uses_from_macos "ncurses"
  uses_from_macos "xz"
  uses_from_macos "zlib"

  def install
    # needed to build clang
    ENV.permit_arch_flags

    # Apple's libstdc++ is too old to build LLVM
    ENV.libcxx if ENV.compiler == :clang

    opamroot = buildpath/"opamroot"
    opamroot.mkpath
    ENV["OPAMROOT"] = opamroot
    ENV["OPAMYES"] = "1"
    ENV["OPAMVERBOSE"] = "1"

    system "opam", "init", "--no-setup", "--disable-sandboxing"

    # do not attempt to use the clang in facebook-clang-plugins/ as it hasn't been built yet
    ENV["INFER_CONFIGURE_OPTS"] = "--prefix=#{prefix} --without-fcp-clang"

    # Let's try build clang faster
    ENV["JOBS"] = ENV.make_jobs.to_s

    # Release build
    touch ".release"

    system "./build-infer.sh", "all", "--yes"
    system "make", "install-with-libs"
  end

  test do
    (testpath/"FailingTest.c").write <<~EOS
      #include <stdio.h>

      int main() {
        int *s = NULL;
        *s = 42;

        return 0;
      }
    EOS

    (testpath/"PassingTest.c").write <<~EOS
      #include <stdio.h>

      int main() {
        int *s = NULL;
        if (s != NULL) {
          *s = 42;
        }

        return 0;
      }
    EOS

    shell_output("#{bin}/infer --fail-on-issue -P -- clang -c FailingTest.c", 2)
    shell_output("#{bin}/infer --fail-on-issue -P -- clang -c PassingTest.c")

    (testpath/"FailingTest.java").write <<~EOS
      class FailingTest {

        String mayReturnNull(int i) {
          if (i > 0) {
            return "Hello, Infer!";
          }
          return null;
        }

        int mayCauseNPE() {
          String s = mayReturnNull(0);
          return s.length();
        }
      }
    EOS

    (testpath/"PassingTest.java").write <<~EOS
      class PassingTest {

        String mayReturnNull(int i) {
          if (i > 0) {
            return "Hello, Infer!";
          }
          return null;
        }

        int mayCauseNPE() {
          String s = mayReturnNull(0);
          return s == null ? 0 : s.length();
        }
      }
    EOS

    shell_output("#{bin}/infer --fail-on-issue -P -- javac FailingTest.java", 2)
    shell_output("#{bin}/infer --fail-on-issue -P -- javac PassingTest.java")
  end
end
