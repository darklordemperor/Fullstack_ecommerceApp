import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';

export interface ApiEnvelope<T> {
  data: T;
  message?: string;
  error?: unknown;
}

export interface AdminStats {
  total_users: number;
  total_products: number;
  total_orders: number;
  total_revenue: number;
}

export interface UserModel {
  id: string;
  name: string;
  lastname: string;
  age: number;
  gender?: string;
  email: string;
  role: string[];
  banned: boolean;
  address?: string;
  profile_image?: string;
  shop_name?: string;
  shop_location?: string;
  tax_payer_number?: string;
  seller_status?: string;
}

export interface ProductModel {
  id: string;
  seller_id: string;
  seller_name: string;
  name: string;
  description: string;
  price: number;
  stock: number;
  category: string;
  images: string[];
}

export interface LoginResult {
  token: string;
  user: UserModel;
}

@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${window.location.protocol}//${window.location.hostname}:8080/api`;

  login(email: string, password: string): Observable<LoginResult> {
    return this.http
      .post<ApiEnvelope<LoginResult>>(`${this.baseUrl}/auth/login`, {
        email,
        password,
      })
      .pipe(map((response) => response.data));
  }

  stats(): Observable<AdminStats> {
    return this.http
      .get<ApiEnvelope<AdminStats>>(`${this.baseUrl}/admin/stats`)
      .pipe(map((response) => response.data));
  }

  users(): Observable<UserModel[]> {
    return this.http
      .get<ApiEnvelope<UserModel[]>>(`${this.baseUrl}/admin/users`)
      .pipe(map((response) => response.data ?? []));
  }

  products(): Observable<ProductModel[]> {
    return this.http
      .get<ApiEnvelope<ProductModel[]>>(`${this.baseUrl}/admin/products`)
      .pipe(map((response) => response.data ?? []));
  }

  setBanned(userId: string, banned: boolean): Observable<unknown> {
    return this.http.put(`${this.baseUrl}/admin/users/${userId}/ban`, {
      banned,
    });
  }

  deleteProduct(productId: string): Observable<unknown> {
    return this.http.delete(`${this.baseUrl}/admin/products/${productId}`);
  }
}
