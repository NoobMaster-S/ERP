"use client";

import React, { createContext, useContext, useState, useEffect } from "react";
import { executeGraphQL } from "../graphql/client";
import { LOGIN_MUTATION } from "../graphql/operations";

export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  isPlatformAdmin: boolean;
}

export interface BusinessSummary {
  id: string;
  name: string;
  slug: string;
  businessType: string;
  roleName: string;
  permissions: string[];
}

interface AuthContextType {
  user: User | null;
  token: string | null;
  activeBusiness: BusinessSummary | null;
  availableBusinesses: BusinessSummary[];
  isLoading: boolean;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => void;
  switchBusiness: (business: BusinessSummary) => void;
  hasPermission: (permissionCode: string) => boolean;
}

const AuthContext = createContext<AuthContextType>({} as AuthContextType);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [activeBusiness, setActiveBusiness] = useState<BusinessSummary | null>(null);
  const [availableBusinesses, setAvailableBusinesses] = useState<BusinessSummary[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  useEffect(() => {
    // Restore session from localStorage if available
    try {
      const storedToken = localStorage.getItem("erp_access_token");
      const storedUser = localStorage.getItem("erp_user");
      const storedBusiness = localStorage.getItem("erp_active_business");
      const storedAllBusinesses = localStorage.getItem("erp_available_businesses");

      if (storedToken && storedUser) {
        setToken(storedToken);
        setUser(JSON.parse(storedUser));
        if (storedBusiness) setActiveBusiness(JSON.parse(storedBusiness));
        if (storedAllBusinesses) setAvailableBusinesses(JSON.parse(storedAllBusinesses));
      }
    } catch {
      // Ignore parse errors
    } finally {
      setIsLoading(false);
    }
  }, []);

  const login = async (email: string, password: string): Promise<boolean> => {
    const res = await executeGraphQL(LOGIN_MUTATION, {
      input: { email, password, deviceName: "Admin Web Panel" },
    });

    if (res.data?.login) {
      const auth = res.data.login;
      setToken(auth.accessToken);
      setUser(auth.user);
      setActiveBusiness(auth.activeBusiness);
      setAvailableBusinesses(auth.availableBusinesses || []);

      localStorage.setItem("erp_access_token", auth.accessToken);
      localStorage.setItem("erp_user", JSON.stringify(auth.user));
      if (auth.activeBusiness) {
        localStorage.setItem("erp_active_business", JSON.stringify(auth.activeBusiness));
      }
      localStorage.setItem(
        "erp_available_businesses",
        JSON.stringify(auth.availableBusinesses || [])
      );
      return true;
    }
    return false;
  };

  const logout = () => {
    setUser(null);
    setToken(null);
    setActiveBusiness(null);
    setAvailableBusinesses([]);
    localStorage.removeItem("erp_access_token");
    localStorage.removeItem("erp_user");
    localStorage.removeItem("erp_active_business");
    localStorage.removeItem("erp_available_businesses");
  };

  const switchBusiness = (business: BusinessSummary) => {
    setActiveBusiness(business);
    localStorage.setItem("erp_active_business", JSON.stringify(business));
  };

  const hasPermission = (permissionCode: string): boolean => {
    if (user?.isPlatformAdmin) return true;
    return activeBusiness?.permissions.includes(permissionCode) ?? false;
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        activeBusiness,
        availableBusinesses,
        isLoading,
        login,
        logout,
        switchBusiness,
        hasPermission,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
