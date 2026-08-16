export interface User {
  id: number;
  email: string;
  displayName?: string | null;
  admin: boolean;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: User;
}
