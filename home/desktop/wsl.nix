{inputs, ...}: {
  imports = [
    "${inputs.self}/home/desktop"
  ];

  home.username = "abhay";
  home.homeDirectory = "/home/abhay";
}
