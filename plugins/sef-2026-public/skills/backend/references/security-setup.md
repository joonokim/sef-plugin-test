# Security Setup Reference

## Authentication Flow

```
Client (Authorization: Bearer token)
  → JwtAuthenticationFilter (validate token, set SecurityContext)
  → Spring Security (WebSecurityConfig, MethodSecurityConfig)
  → Controller (@PreAuthorize with custom expressions)
```

## Directory Structure

```
infra/security/
├── config/
│   ├── WebSecurityConfig.java        # HTTP security rules
│   ├── MethodSecurityConfig.java     # Method-level security
│   ├── WebConfig.java                # CORS settings
│   └── BCryptConfig.java            # Password encoder
├── jwt/
│   ├── JwtTokenProvider.java         # Token create/validate
│   ├── JwtAuthenticationFilter.java  # Request filter
│   ├── JwtAuthenticationEntryPoint.java
│   ├── JwtAccessDeniedHandler.java
│   ├── JwtTokenStore.java
│   └── JwtUtils.java
├── expression/
│   ├── MenuSecurityExpressionRoot.java   # Custom hasMenuAuthority()
│   └── MenuSecurityExpressionHandler.java
├── service/
│   ├── CustomUserDetailsService.java
│   └── CustomUserDetails.java
└── common/
    ├── SecurityUser.java
    └── AuthenticationResult.java
```

## WebSecurityConfig

Uses Spring Security 5.x style (`antMatchers`, NOT `requestMatchers`):

```java
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class WebSecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
            .cors().configurationSource(corsConfigurationSource())
            .and()
            .sessionManagement().sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            .and()
            .exceptionHandling()
                .authenticationEntryPoint(jwtAuthenticationEntryPoint)
                .accessDeniedHandler(jwtAccessDeniedHandler)
            .and()
            .authorizeRequests()
                .antMatchers(JWT_AUTH_WHITELIST).permitAll()
                .antMatchers(getIgnoredPaths()).permitAll()
                .antMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .antMatchers(adminPaths.split(",")).hasAuthority("USER_ROLE_ADM")
                .antMatchers(apiPaths.split(",")).authenticated()
                .antMatchers("/api/v1/boards/**").permitAll()
                .anyRequest().permitAll()
            .and()
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
```

**Important**: Spring Boot 2.7 uses `antMatchers()`. Do NOT use `requestMatchers()` (that's Spring Security 6.x / Spring Boot 3.x).

## Custom Security Expression: hasMenuAuthority

Menu-based CRUD permission system specific to government projects.

```java
// MenuSecurityExpressionRoot.java
public boolean hasMenuAuthority(String menuId, String authrtCd) {
    String username = getAuthentication().getName();
    return menuRoleService.hasMenuAuthority(username, menuId, authrtCd);
}
```

Permission codes: `C` = Create, `R` = Read, `U` = Update, `D` = Delete.

## Controller Permission Examples

```java
@Tag(name = "Board", description = "Board CRUD API")
@RestController
@RequestMapping("/api/v1/menus/{menuId}/boards")
public class BoardController {

    @GetMapping
    @PreAuthorize("hasMenuAuthority(#menuId, 'R')")
    public ResponseEntity<ApiResponse<PageResponse<BoardListResponse>>> list(...) { }

    @PostMapping
    @PreAuthorize("isAuthenticated() and hasMenuAuthority(#menuId, 'C')")
    public ResponseEntity<ApiResponse<Void>> create(...) { }

    @PostMapping("/{bbsSq}/update")
    @PreAuthorize("isAuthenticated() and hasMenuAuthority(#menuId, 'U')")
    public ResponseEntity<ApiResponse<BoardDetailResponse>> update(...) { }

    @PostMapping("/{bbsSq}/delete")
    @PreAuthorize("isAuthenticated() and hasMenuAuthority(#menuId, 'D')")
    public ResponseEntity<ApiResponse<Void>> delete(...) { }
}
```

Compound expressions:
```java
@PreAuthorize("hasRole('ADMIN') or hasMenuAuthority(#menuId, 'D')")
```

## JWT Configuration

```yaml
security:
  jwt:
    secret-key: ${JWT_SECRET}
    token-validity: 3600000           # 1 hour (access token)
    refresh-token-validity: 604800000 # 7 days
```

## Checklist

- [ ] `antMatchers` used (NOT `requestMatchers`) for Spring Security 5.x
- [ ] JWT filter added before `UsernamePasswordAuthenticationFilter`
- [ ] CSRF disabled (stateless JWT)
- [ ] `@PreAuthorize` annotations on all controller methods
- [ ] `hasMenuAuthority(#menuId, 'X')` for menu-based permissions
- [ ] JWT secret at least 256 bits (32+ characters)
