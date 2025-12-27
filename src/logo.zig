const std = @import("std");

const reset = "\x1b[0m";

const cyan = "\x1b[36m";
const blue = "\x1b[34m";
const magenta = "\x1b[35m";
const orange = "\x1b[38;5;208m";
const red = "\x1b[31m";

const default_logo = [_][]const u8{
    cyan ++ "        #####" ++ reset,
    cyan ++ "       #######" ++ reset,
    cyan ++ "       ##" ++ reset ++ "O" ++ cyan ++ "#" ++ reset ++ "O" ++ cyan ++ "##" ++ reset,
    cyan ++ "       #" ++ orange ++ "#####" ++ cyan ++ "#" ++ reset,
    cyan ++ "     ##" ++ reset ++ "##" ++ orange ++ "###" ++ reset ++ "##" ++ cyan ++ "##" ++ reset,
    cyan ++ "    #" ++ reset ++ "##########" ++ cyan ++ "##" ++ reset,
    cyan ++ "   #" ++ reset ++ "############" ++ cyan ++ "##" ++ reset,
    cyan ++ "   #" ++ reset ++ "############" ++ cyan ++ "###" ++ reset,
    orange ++ "  ##" ++ cyan ++ "#" ++ reset ++ "###########" ++ cyan ++ "##" ++ orange ++ "#" ++ reset,
    orange ++ "######" ++ cyan ++ "#" ++ reset ++ "#######" ++ cyan ++ "#" ++ orange ++ "######" ++ reset,
    orange ++ "#######" ++ cyan ++ "#" ++ reset ++ "#####" ++ cyan ++ "#" ++ orange ++ "#######" ++ reset,
    orange ++ "  #####" ++ cyan ++ "#######" ++ orange ++ "#####" ++ reset,
};

const arch_logo = [_][]const u8{
    blue ++ "                  -`" ++ reset,
    blue ++ "                 .o+`" ++ reset,
    blue ++ "                `ooo/" ++ reset,
    blue ++ "               `+oooo:" ++ reset,
    blue ++ "              `+oooooo:" ++ reset,
    blue ++ "              -+oooooo+:" ++ reset,
    blue ++ "            `/:-:++oooo+:" ++ reset,
    blue ++ "           `/++++/+++++++:" ++ reset,
    blue ++ "          `/++++++++++++++:" ++ reset,
    blue ++ "         `/+++o" ++ cyan ++ "oooooooo" ++ blue ++ "oooo/" ++ reset,
    blue ++ "        ./" ++ cyan ++ "ooosssso++osssssso" ++ blue ++ "+`" ++ reset,
    cyan ++ "       .oossssso-````/ossssss+`" ++ reset,
    cyan ++ "      -osssssso.      :ssssssso." ++ reset,
    cyan ++ "     :osssssss/        osssso+++" ++ reset ++ ".",
    cyan ++ "    /ossssssss/        +ssssooo/-" ++ reset,
    blue ++ "  `/ossssso+/:-        -:/+osssso+-" ++ reset,
    blue ++ " `+sso+:-`                 `.-/+oso:" ++ reset,
    blue ++ "`++:.                           `-/+/" ++ reset,
    blue ++ ".`                                 `/" ++ reset,
};

const ubuntu_logo = [_][]const u8{
    reset ++ "                             ....",
    orange ++ "              '.,:clooo:  " ++ reset ++ ".:looooo:.",
    orange ++ "           .;looooooooc  " ++ reset ++ ".oooooooooo'",
    orange ++ "        .;looooool:,''.  " ++ reset ++ ":ooooooooooc",
    orange ++ "       ;looool;.         " ++ reset ++ "'oooooooooo,",
    orange ++ "      ;clool'             " ++ reset ++ ".cooooooc.  " ++ orange ++ ",," ++ reset,
    orange ++ "         ...                " ++ reset ++ "......  " ++ orange ++ ".:oo," ++ reset,
    reset ++ "  .;clol:,.                        " ++ orange ++ ".loooo'",
    reset ++ " :ooooooooo,                        " ++ orange ++ "'ooool",
    reset ++ "'ooooooooooo.                        " ++ orange ++ "loooo.",
    reset ++ "'ooooooooool                         " ++ orange ++ "coooo.",
    reset ++ " ,loooooooc.                        " ++ orange ++ ".loooo.",
    reset ++ "   .,;;;'.                          " ++ orange ++ ";ooooc",
    orange ++ "       ...                         ,ooool." ++ reset,
    orange ++ "    .cooooc.              " ++ reset ++ "..',,'.  " ++ orange ++ ".cooo.",
    orange ++ "      ;ooooo:.           " ++ reset ++ ";oooooooc.  " ++ orange ++ ":l.",
    orange ++ "       .coooooc,..      " ++ reset ++ "coooooooooo.",
    orange ++ "         .:ooooooolc:. " ++ reset ++ ".ooooooooooo'",
    orange ++ "           .':loooooo;  " ++ reset ++ ",oooooooooc",
    orange ++ "               ..';::c'  " ++ reset ++ ".;loooo:'",
};

const debian_logo = [_][]const u8{
    magenta ++ "        _,met$$$$$$$$$$gg." ++ reset,
    magenta ++ "     ,g$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$P." ++ reset,
    magenta ++ "   ,g$$$$P\"\"       \"\"\"Y$$$$.\"." ++ reset,
    magenta ++ "  ,$$$$P'              `$$$$$$." ++ reset,
    magenta ++ "',$$$$P       ,ggs.     `$$$$b:" ++ reset,
    magenta ++ "`d$$$$'     ,$P\"'   " ++ reset ++ ".$" ++ magenta ++ "    $$$$$$" ++ reset,
    magenta ++ " $$$$P      d$'     " ++ reset ++ ",$" ++ magenta ++ "    $$$$P" ++ reset,
    magenta ++ " $$$$:      $$$.   " ++ reset ++ "-" ++ magenta ++ "    ,d$$$$'" ++ reset,
    magenta ++ " $$$$;      Y$b._   _,d$P'" ++ reset,
    magenta ++ " Y$$$$.    " ++ reset ++ "`." ++ magenta ++ "`\"Y$$$$$$$$P\"'" ++ reset,
    magenta ++ " `$$$$b      " ++ reset ++ "\"-.__" ++ reset,
    magenta ++ "  `Y$$$$b" ++ reset,
    magenta ++ "   `Y$$$$." ++ reset,
    magenta ++ "     `$$$$b." ++ reset,
    magenta ++ "       `Y$$$$b." ++ reset,
    magenta ++ "         `\"Y$$b._" ++ reset,
    magenta ++ "             `\"\"\"\"" ++ reset,
};

const fedora_logo = [_][]const u8{
    reset ++ "             .',;::::;,'." ++ reset,
    reset ++ "         .';:cccccccccccc:;,." ++ reset,
    reset ++ "      .;cccccccccccccccccccccc;." ++ reset,
    reset ++ "    .:cccccccccccccccccccccccccc:." ++ reset,
    reset ++ "  .;ccccccccccccc;" ++ blue ++ ".:dddl:." ++ reset ++ ";ccccccc;." ++ reset,
    reset ++ " .:ccccccccccccc;" ++ blue ++ "OWMKOOXMWd" ++ reset ++ ";ccccccc:." ++ reset,
    reset ++ ".:ccccccccccccc;" ++ blue ++ "KMMc" ++ reset ++ ";cc;" ++ blue ++ "xMMc" ++ reset ++ ";ccccccc:." ++ reset,
    reset ++ ",cccccccccccccc;" ++ blue ++ "MMM." ++ reset ++ ";cc;" ++ blue ++ ";WW:" ++ reset ++ ";cccccccc," ++ reset,
    reset ++ ":cccccccccccccc;" ++ blue ++ "MMM." ++ reset ++ ";cccccccccccccccc:" ++ reset,
    reset ++ ":ccccccc;" ++ blue ++ "oxOOOo" ++ reset ++ ";" ++ blue ++ "MMM000k." ++ reset ++ ";cccccccccccc:" ++ reset,
    reset ++ "cccccc;" ++ blue ++ "0MMKxdd:" ++ reset ++ ";" ++ blue ++ "MMMkddc." ++ reset ++ ";cccccccccccc;" ++ reset,
    reset ++ "ccccc;" ++ blue ++ "XMO'" ++ reset ++ ";cccc;" ++ blue ++ "MMM." ++ reset ++ ";cccccccccccccccc'" ++ reset,
    reset ++ "ccccc;" ++ blue ++ "MMo" ++ reset ++ ";ccccc;" ++ blue ++ "MMW." ++ reset ++ ";ccccccccccccccc;" ++ reset,
    reset ++ "ccccc;" ++ blue ++ "0MNc." ++ reset ++ "ccc" ++ blue ++ ".xMMd" ++ reset ++ ";ccccccccccccccc;" ++ reset,
    reset ++ "cccccc;" ++ blue ++ "dNMWXXXWM0:" ++ reset ++ ";cccccccccccccc:," ++ reset,
    reset ++ "cccccccc;" ++ blue ++ ".:odl:." ++ reset ++ ";cccccccccccccc:,." ++ reset,
    reset ++ "ccccccccccccccccccccccccccccc:'." ++ reset,
    reset ++ ":ccccccccccccccccccccccc:;,.." ++ reset,
    reset ++ " ':cccccccccccccccc::;,." ++ reset,
};

const nix_logo = [_][]const u8{
    blue ++ "          ▗▄▄▄       " ++ cyan ++ "▗▄▄▄▄    ▄▄▄▖" ++ reset,
    blue ++ "          ▜███▙       " ++ cyan ++ "▜███▙  ▟███▛" ++ reset,
    blue ++ "           ▜███▙       " ++ cyan ++ "▜███▙▟███▛" ++ reset,
    blue ++ "            ▜███▙       " ++ cyan ++ "▜██████▛" ++ reset,
    blue ++ "     ▟█████████████████▙ " ++ cyan ++ "▜████▛     " ++ blue ++ "▟▙" ++ reset,
    blue ++ "    ▟███████████████████▙ " ++ cyan ++ "▜███▙    " ++ blue ++ "▟██▙" ++ reset,
    cyan ++ "           ▄▄▄▄▖           ▜███▙  " ++ blue ++ "▟███▛" ++ reset,
    cyan ++ "          ▟███▛             ▜██▛ " ++ blue ++ "▟███▛" ++ reset,
    cyan ++ "         ▟███▛               ▜▛ " ++ blue ++ "▟███▛" ++ reset,
    cyan ++ "▟███████████▛                  " ++ blue ++ "▟██████████▙" ++ reset,
    cyan ++ "▜██████████▛                  " ++ blue ++ "▟███████████▛" ++ reset,
    cyan ++ "      ▟███▛ " ++ blue ++ "▟▙               ▟███▛" ++ reset,
    cyan ++ "     ▟███▛ " ++ blue ++ "▟██▙             ▟███▛" ++ reset,
    cyan ++ "    ▟███▛  " ++ blue ++ "▜███▙           ▝▀▀▀▀" ++ reset,
    cyan ++ "    ▜██▛    " ++ blue ++ "▜███▙ " ++ cyan ++ "▜██████████████████▛" ++ reset,
    cyan ++ "     ▜▛     " ++ blue ++ "▟████▙ " ++ cyan ++ "▜████████████████▛" ++ reset,
    blue ++ "           ▟██████▙       " ++ cyan ++ "▜███▙" ++ reset,
    blue ++ "          ▟███▛▜███▙       " ++ cyan ++ "▜███▙" ++ reset,
    blue ++ "         ▟███▛  ▜███▙       " ++ cyan ++ "▜███▙" ++ reset,
    blue ++ "         ▝▀▀▀    ▀▀▀▀▘       " ++ cyan ++ "▀▀▀▘" ++ reset,
};

const windows_logo = [_][]const u8{
    cyan ++ "                                  .., " ++ reset,
    cyan ++ "                      ....,,:;+ccllll" ++ reset,
    cyan ++ "        ...,,+:;  cllllllllllllllllll" ++ reset,
    cyan ++ "  ,cclllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "                                      " ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  llllllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "  `'ccllllllllll  lllllllllllllllllll" ++ reset,
    cyan ++ "        `' \\*::  :ccllllllllllllllll" ++ reset,
    cyan ++ "                       ````''*::cllll" ++ reset,
    cyan ++ "                                 ````" ++ reset,
};

pub fn pick(os_id: ?[]const u8) []const []const u8 {
    if (os_id) |id| {
        if (std.ascii.eqlIgnoreCase(id, "windows")) return windows_logo[0..];
        if (std.ascii.eqlIgnoreCase(id, "arch")) return arch_logo[0..];
        if (std.ascii.eqlIgnoreCase(id, "ubuntu")) return ubuntu_logo[0..];
        if (std.ascii.eqlIgnoreCase(id, "debian")) return debian_logo[0..];
        if (std.ascii.eqlIgnoreCase(id, "fedora")) return fedora_logo[0..];
        if (std.ascii.eqlIgnoreCase(id, "nixos")) return nix_logo[0..];
    }
    return default_logo[0..];
}
