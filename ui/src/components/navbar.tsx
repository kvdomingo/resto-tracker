import { Link } from "@tanstack/react-router";
import { PlusIcon, SearchIcon, XIcon } from "lucide-react";
import { useMemo, useState } from "react";
import { useDebounceCallback } from "usehooks-ts";
import {
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
} from "@/components/ui/input-group.tsx";
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuList,
} from "@/components/ui/navigation-menu.tsx";
import { useRootQueryStates } from "@/hooks/use-root-query-states";
import { $api } from "@/lib/api";
import { Avatar, AvatarFallback } from "./ui/avatar";
import { Button } from "./ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "./ui/dropdown-menu";

export function Navbar() {
  const [{ search }, setState] = useRootQueryStates();
  const [innerSearch, setInnerSearch] = useState(search);
  const debouncedSetSearch = useDebounceCallback((search) => {
    setState({ search });
  }, 300);

  const { data: loginUrl } = $api.useQuery("get", "/api/auth/login", {
    parseAs: "text",
  });

  const { data: me } = $api.useQuery("get", "/api/auth/me");
  const isLoggedIn = me != null;

  const avatarFallback = useMemo(() => {
    if (me == null) return null;

    if (me.name != null && me.name.length > 0) {
      return me.name
        .split(" ")
        .map((word) => word.at(0)?.toUpperCase() ?? "")
        .join("");
    }
    return me.email.slice(0, 2).toUpperCase();
  }, [me]);

  const myName = useMemo(() => (me ? (me.name ?? me.email) : "User"), [me]);

  return (
    <NavigationMenu className="p-4 bg-secondary w-full max-w-full [&>div:has(>ul)]:w-full">
      <NavigationMenuList className="flex justify-between w-full">
        <NavigationMenuItem className="basis-1/3 small-caps tracking-widest">
          RestoTracker
        </NavigationMenuItem>
        <NavigationMenuItem className="basis-1/3 flex justify-center">
          <InputGroup className="w-64 focus-within:w-100 transition-[width] duration-300">
            <InputGroupInput
              value={innerSearch}
              onChange={(e) => {
                setInnerSearch(e.target.value);
                debouncedSetSearch(e.target.value);
              }}
              placeholder="Search restaurants..."
            />
            <InputGroupAddon>
              <SearchIcon />
            </InputGroupAddon>
            {innerSearch && (
              <InputGroupAddon align="inline-end">
                <Button
                  variant="ghost"
                  size="icon-xs"
                  onClick={() => {
                    setInnerSearch("");
                    debouncedSetSearch("");
                  }}
                >
                  <XIcon />
                </Button>
              </InputGroupAddon>
            )}
          </InputGroup>
        </NavigationMenuItem>
        <div className="basis-1/3 flex justify-end items-center gap-2">
          {isLoggedIn && (
            <NavigationMenuItem>
              <Button variant="ghost" size="icon-sm">
                <PlusIcon />
              </Button>
            </NavigationMenuItem>
          )}
          <NavigationMenuItem>
            {isLoggedIn ? (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Avatar className="cursor-pointer">
                    <AvatarFallback>{avatarFallback}</AvatarFallback>
                  </Avatar>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuLabel>
                    Hello, <b>{myName}</b>
                  </DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  <DropdownMenuGroup>
                    <DropdownMenuItem asChild>
                      <a href="/api/auth/logout" className="text-foreground">
                        Logout
                      </a>
                    </DropdownMenuItem>
                  </DropdownMenuGroup>
                </DropdownMenuContent>
              </DropdownMenu>
            ) : (
              <Button asChild disabled={!loginUrl}>
                <Link to={loginUrl}>Login</Link>
              </Button>
            )}
          </NavigationMenuItem>
        </div>
      </NavigationMenuList>
    </NavigationMenu>
  );
}
