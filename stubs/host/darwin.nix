{ wed, ... }:
wed.mkDarwin (
  { ... }:
  {
    # Import the generated configuration 
    imports = [ ./configuration.nix ];

    # These are module that are for configuring the host,
    # This should include hardware config as well as programs and services needed by all users
    # GPU / CPU / Networking / A greeter etc
    modules = {

    };

    # Tell the wed flake to enable all the default settings for Tom, found in $FLAKE_ROOT/users/
    wed.users = {
      # tom.enable = true;
    };

    # Now enable user modules that are only used on this host
    home-manager.users = {
      # tom = {
      #   modules = {
      #     games = {
      #       factorio.enable = true;
      #     };
      #   };
      # };
    };
  }
)
