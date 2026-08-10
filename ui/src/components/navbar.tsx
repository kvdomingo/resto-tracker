import { PlusIcon, SearchIcon, XIcon } from "lucide-react";
import { useState } from "react";
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

  // Mock login
  const [isLoggedIn, setIsLoggedIn] = useState(false);

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
                  <Avatar>
                    <AvatarFallback>S</AvatarFallback>
                  </Avatar>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuLabel>
                    Hello, <b>System</b>
                  </DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  <DropdownMenuGroup>
                    <DropdownMenuItem onClick={() => setIsLoggedIn(false)}>
                      Logout
                    </DropdownMenuItem>
                  </DropdownMenuGroup>
                </DropdownMenuContent>
              </DropdownMenu>
            ) : (
              <Button onClick={() => setIsLoggedIn(true)}>Login</Button>
            )}
          </NavigationMenuItem>
        </div>
      </NavigationMenuList>
    </NavigationMenu>
  );
}
