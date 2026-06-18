import { CommonModule } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';

import { AdminStats, ApiService, ProductModel, UserModel } from './api.service';

type DashboardTab = 'users' | 'products';

@Component({
  selector: 'app-root',
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  private readonly api = inject(ApiService);

  readonly email = signal('admin@example.com');
  readonly password = signal('abc12345');
  readonly token = signal(localStorage.getItem('admin_token') ?? '');
  readonly admin = signal<UserModel | null>(this.readStoredAdmin());
  readonly loading = signal(false);
  readonly actionLoading = signal('');
  readonly error = signal('');
  readonly activeTab = signal<DashboardTab>('users');
  readonly search = signal('');
  readonly userFilter = signal<'all' | 'active' | 'banned' | 'admin'>('all');

  readonly stats = signal<AdminStats>({
    total_users: 0,
    total_products: 0,
    total_orders: 0,
    total_revenue: 0,
  });
  readonly users = signal<UserModel[]>([]);
  readonly products = signal<ProductModel[]>([]);

  readonly isLoggedIn = computed(() => Boolean(this.token()));
  readonly activeUsers = computed(() => this.users().filter((user) => !user.banned).length);
  readonly bannedUsers = computed(() => this.users().filter((user) => user.banned).length);
  readonly sellers = computed(
    () => this.users().filter((user) => user.role.includes('seller')).length,
  );
  readonly lowStockProducts = computed(
    () => this.products().filter((product) => product.stock <= 5).length,
  );
  readonly filteredUsers = computed(() => {
    const query = this.search().trim().toLowerCase();
    return this.users().filter((user) => {
      const matchesQuery =
        !query ||
        `${user.name} ${user.lastname}`.toLowerCase().includes(query) ||
        user.email.toLowerCase().includes(query) ||
        user.role.join(',').toLowerCase().includes(query);
      const filter = this.userFilter();
      const matchesFilter =
        filter === 'all' ||
        (filter === 'active' && !user.banned) ||
        (filter === 'banned' && user.banned) ||
        (filter === 'admin' && user.role.includes('admin'));
      return matchesQuery && matchesFilter;
    });
  });
  readonly filteredProducts = computed(() => {
    const query = this.search().trim().toLowerCase();
    return this.products().filter((product) => {
      return (
        !query ||
        product.name.toLowerCase().includes(query) ||
        product.seller_name.toLowerCase().includes(query) ||
        product.category.toLowerCase().includes(query)
      );
    });
  });

  constructor() {
    if (this.isLoggedIn()) {
      this.loadDashboard();
    }
  }

  login(): void {
    this.error.set('');
    this.loading.set(true);
    this.api.login(this.email(), this.password()).subscribe({
      next: (result) => {
        if (!result.user.role.includes('admin')) {
          this.error.set('This account does not have admin access.');
          this.loading.set(false);
          return;
        }
        localStorage.setItem('admin_token', result.token);
        localStorage.setItem('admin_user', JSON.stringify(result.user));
        this.token.set(result.token);
        this.admin.set(result.user);
        this.loading.set(false);
        this.loadDashboard();
      },
      error: (error: HttpErrorResponse) => {
        this.error.set(this.errorMessage(error, 'Unable to sign in.'));
        this.loading.set(false);
      },
    });
  }

  logout(): void {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
    this.token.set('');
    this.admin.set(null);
    this.users.set([]);
    this.products.set([]);
    this.search.set('');
    this.activeTab.set('users');
  }

  loadDashboard(): void {
    this.error.set('');
    this.loading.set(true);
    forkJoin({
      stats: this.api.stats(),
      users: this.api.users(),
      products: this.api.products(),
    }).subscribe({
      next: ({ stats, users, products }) => {
        this.stats.set(stats);
        this.users.set(users);
        this.products.set(products);
        this.loading.set(false);
      },
      error: (error: HttpErrorResponse) => {
        this.error.set(this.errorMessage(error, 'Unable to load dashboard.'));
        this.loading.set(false);
      },
    });
  }

  setUserBanned(user: UserModel, banned: boolean): void {
    this.actionLoading.set(user.id);
    this.api.setBanned(user.id, banned).subscribe({
      next: () => {
        this.users.update((users) =>
          users.map((item) => (item.id === user.id ? { ...item, banned } : item)),
        );
        this.actionLoading.set('');
        this.loadDashboard();
      },
      error: (error: HttpErrorResponse) => {
        this.error.set(this.errorMessage(error, 'Unable to update user.'));
        this.actionLoading.set('');
      },
    });
  }

  deleteProduct(product: ProductModel): void {
    const confirmed = window.confirm(`Delete "${product.name}"?`);
    if (!confirmed) return;

    this.actionLoading.set(product.id);
    this.api.deleteProduct(product.id).subscribe({
      next: () => {
        this.products.update((products) => products.filter((item) => item.id !== product.id));
        this.actionLoading.set('');
        this.loadDashboard();
      },
      error: (error: HttpErrorResponse) => {
        this.error.set(this.errorMessage(error, 'Unable to delete product.'));
        this.actionLoading.set('');
      },
    });
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('th-TH', {
      style: 'currency',
      currency: 'THB',
      maximumFractionDigits: 0,
    }).format(value || 0);
  }

  initials(user: UserModel): string {
    return `${user.name?.[0] ?? ''}${user.lastname?.[0] ?? ''}`.toUpperCase();
  }

  productImage(product: ProductModel): string {
    return product.images?.find(Boolean) ?? `https://picsum.photos/seed/${product.id}/160`;
  }

  private readStoredAdmin(): UserModel | null {
    const value = localStorage.getItem('admin_user');
    if (!value) return null;
    try {
      return JSON.parse(value) as UserModel;
    } catch {
      return null;
    }
  }

  private errorMessage(error: HttpErrorResponse, fallback: string): string {
    if (error.status === 0) {
      return 'Cannot connect to backend. Check Docker and port 8080.';
    }
    const apiError = error.error?.error;
    if (typeof apiError === 'string') return apiError;
    return fallback;
  }
}
