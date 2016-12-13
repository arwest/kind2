# Kind 2 dependencies.
OPAM_DEPENDS="ocamlfind menhir camlp4"

sudo apt-get update -y -qq
sudo apt-get install -y -qq ocaml ocaml-native-compilers


# Retrieve opam.
wget -qq https://raw.github.com/ocaml/opam/master/shell/opam_installer.sh -O - | sh -s /usr/local/bin
echo "y" | opam init
eval $(opam config env)
opam update
opam switch 4.04.0

# Install ocaml packages needed for Kind 2
echo "y" | opam install ocamlfind camlp4 menhir
echo "y" | opam init && eval $(opam config env) && opam switch reinstall system
eval $(opam config env)

./autogen.sh
./build.sh
make test