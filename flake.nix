{
  description = "(I Reveal My Attributes- IRMA Server)";

  inputs.nixpkgs.url = "nixpkgs/nixos-20.09";

  # Upstream source tree(s).
  inputs.irma-server-src = { url = git+https://github.com/privacybydesign/irmago.git; flake = false; };

  outputs = { self, nixpkgs, irma-server-src }:
    let

      version = builtins.substring 0 8 irma-server-src.lastModifiedDate;

      supportedSystems = [ "x86_64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        irma-server = with final; buildGoModule rec {
          name = "irma-server-${version}";

          src = irma-server-src;

          vendorSha256 =  "sha256-9JZKl5hm3qtbYNwPFyDSzndhw6/Qr2DN/CY3eSNDMxU=";

         checkPhase = ''
          echo "Testing requres postgresql and MailHog which are not required for operation hence it is done only in nix develop"
          '';

          meta = {
            homepage = "https://privacybydesign.foundation/irma-explanation/";
            description = "This program is IRMA server.
            IRMA stands for I Reveal My Attributes. 
            IRMA empowers you to disclose online,
            via your mobile phone, certain attributes of yourself";
          };
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) irma-server;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.irma-server);

      
      devShell = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlay ];
          };

        in
        pkgs.mkShell {


          buildInputs = with pkgs; [
            go
            postgresql
            mailhog
          ];

          shellHook = ''
              export PGHOST=$HOME/postgres
              export PGDATA=$PGHOST/data
              export PGDATABASE=postgres
              export PGLOG=$PGHOST/postgres.log
            
              if pg_ctl status 
              then 
              pg_ctl stop
              fi

              if [ ! -d $PGDATA ]; then
                initdb -U postgres --auth=trust --no-locale --encoding=UTF8
              fi
              
              pg_ctl -D $PGDATA -l $PGLOG -o "-k /tmp" -o "-F -p 5432" start
              
              if  pg_ctl status
              then
              createuser -h localhost -s postgres

              psql -U postgres -h localhost -c 'CREATE database test'
              psql -U postgres -h localhost -c "CREATE USER testuser with encrypted password 'testpassword'"
              psql -U postgres -h localhost -c 'grant all privileges on database test to testuser'
              fi
            '';



        });

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems (system: {
         inherit (self.packages.${system}) irma-server;
         test =
         with nixpkgsFor.${system};
        stdenv.mkDerivation {
            name = "irma-server-test-${version}";

            buildInputs = [ irma-server go postgresql mailhog ];

            src = irma-server-src;
          
            vendorSha256 =  "sha256-9JZKl5hm3qtbYNwPFyDSzndhw6/Qr2DN/CY3eSNDMxU=";

            unpackPhase = "true";

            postInstall = ''
               export PGHOST=$HOME/postgres
              export PGDATA=$PGHOST/data
              export PGDATABASE=postgres
              export PGLOG=$PGHOST/postgres.log
            
              if pg_ctl status 
              then 
              pg_ctl stop
              fi

              if [ ! -d $PGDATA ]; then
                initdb -U postgres --auth=trust --no-locale --encoding=UTF8
              fi
              
              pg_ctl -D $PGDATA -l $PGLOG -o "-k /tmp" -o "-F -p 5432" start
              
              if  pg_ctl status
              then
              createuser -h localhost -s postgres

              psql -U postgres -h localhost -c 'CREATE database test'
              psql -U postgres -h localhost -c "CREATE USER testuser with encrypted password 'testpassword'"
              psql -U postgres -h localhost -c 'grant all privileges on database test to testuser'
              fi
              go test ./...  
            '';


            installPhase = "mkdir -p $out";
          };
        

      });

    };
}
