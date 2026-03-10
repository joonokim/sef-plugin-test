#!/usr/bin/env python3
"""
Spring Boot API 스캐폴딩 자동 생성 스크립트

사용법:
    python generate_api_scaffold.py <entity_name> <package_name>

예시:
    python generate_api_scaffold.py Product com.example.backend
"""

import os
import sys
from pathlib import Path


def to_camel_case(snake_str):
    """snake_case를 camelCase로 변환"""
    components = snake_str.split('_')
    return components[0] + ''.join(x.title() for x in components[1:])


def to_pascal_case(snake_str):
    """snake_case를 PascalCase로 변환"""
    return ''.join(x.title() for x in snake_str.split('_'))


def create_entity(entity_name, package_name, output_dir):
    """Entity 클래스 생성"""
    content = f'''package {package_name}.domain;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Table(name = "{entity_name.lower()}s")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class {entity_name} {{

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @Builder
    public {entity_name}(String name) {{
        this.name = name;
    }}

    public void update(String name) {{
        this.name = name;
    }}
}}
'''

    file_path = output_dir / 'domain' / f'{entity_name}.java'
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content)
    print(f'✓ Created: {file_path}')


def create_repository(entity_name, package_name, output_dir):
    """Repository 인터페이스 생성"""
    content = f'''package {package_name}.repository;

import {package_name}.domain.{entity_name};
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface {entity_name}Repository extends JpaRepository<{entity_name}, Long> {{

    List<{entity_name}> findByNameContaining(String name);
}}
'''

    file_path = output_dir / 'repository' / f'{entity_name}Repository.java'
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content)
    print(f'✓ Created: {file_path}')


def create_request_dto(entity_name, package_name, output_dir):
    """Request DTO 생성"""
    content = f'''package {package_name}.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class {entity_name}CreateRequest {{

    @NotBlank(message = "이름은 필수입니다")
    @Size(max = 100, message = "이름은 100자를 초과할 수 없습니다")
    private String name;
}}
'''

    file_path = output_dir / 'dto' / 'request' / f'{entity_name}CreateRequest.java'
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content)
    print(f'✓ Created: {file_path}')


def create_response_dto(entity_name, package_name, output_dir):
    """Response DTO 생성"""
    content = f'''package {package_name}.dto.response;

import {package_name}.domain.{entity_name};
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class {entity_name}Response {{

    private Long id;
    private String name;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static {entity_name}Response from({entity_name} entity) {{
        return {entity_name}Response.builder()
            .id(entity.getId())
            .name(entity.getName())
            .createdAt(entity.getCreatedAt())
            .updatedAt(entity.getUpdatedAt())
            .build();
    }}
}}
'''

    file_path = output_dir / 'dto' / 'response' / f'{entity_name}Response.java'
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content)
    print(f'✓ Created: {file_path}')


def create_service(entity_name, package_name, output_dir):
    """Service 클래스 생성"""
    entity_var = to_camel_case(entity_name)
    content = f'''package {package_name}.service;

import {package_name}.domain.{entity_name};
import {package_name}.dto.request.{entity_name}CreateRequest;
import {package_name}.dto.response.{entity_name}Response;
import {package_name}.exception.{entity_name}NotFoundException;
import {package_name}.repository.{entity_name}Repository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class {entity_name}Service {{

    private final {entity_name}Repository {entity_var}Repository;

    public Page<{entity_name}Response> get{entity_name}s(Pageable pageable) {{
        return {entity_var}Repository.findAll(pageable)
            .map({entity_name}Response::from);
    }}

    public {entity_name}Response get{entity_name}(Long id) {{
        {entity_name} {entity_var} = {entity_var}Repository.findById(id)
            .orElseThrow(() -> new {entity_name}NotFoundException(id));
        return {entity_name}Response.from({entity_var});
    }}

    @Transactional
    public {entity_name}Response create{entity_name}({entity_name}CreateRequest request) {{
        {entity_name} {entity_var} = {entity_name}.builder()
            .name(request.getName())
            .build();

        {entity_name} saved = {entity_var}Repository.save({entity_var});
        return {entity_name}Response.from(saved);
    }}

    @Transactional
    public {entity_name}Response update{entity_name}(Long id, {entity_name}CreateRequest request) {{
        {entity_name} {entity_var} = {entity_var}Repository.findById(id)
            .orElseThrow(() -> new {entity_name}NotFoundException(id));

        {entity_var}.update(request.getName());
        return {entity_name}Response.from({entity_var});
    }}

    @Transactional
    public void delete{entity_name}(Long id) {{
        if (!{entity_var}Repository.existsById(id)) {{
            throw new {entity_name}NotFoundException(id);
        }}
        {entity_var}Repository.deleteById(id);
    }}
}}
'''

    file_path = output_dir / 'service' / f'{entity_name}Service.java'
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content)
    print(f'✓ Created: {file_path}')


def create_controller(entity_name, package_name, output_dir):
    """Controller 클래스 생성"""
    entity_var = to_camel_case(entity_name)
    entity_plural = f'{entity_var}s'
    content = f'''package {package_name}.controller;

import {package_name}.dto.request.{entity_name}CreateRequest;
import {package_name}.dto.response.{entity_name}Response;
import {package_name}.service.{entity_name}Service;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/{entity_plural}")
@RequiredArgsConstructor
public class {entity_name}Controller {{

    private final {entity_name}Service {entity_var}Service;

    @GetMapping
    public ResponseEntity<Page<{entity_name}Response>> get{entity_name}s(Pageable pageable) {{
        Page<{entity_name}Response> {entity_plural} = {entity_var}Service.get{entity_name}s(pageable);
        return ResponseEntity.ok({entity_plural});
    }}

    @GetMapping("/{{id}}")
    public ResponseEntity<{entity_name}Response> get{entity_name}(@PathVariable Long id) {{
        {entity_name}Response {entity_var} = {entity_var}Service.get{entity_name}(id);
        return ResponseEntity.ok({entity_var});
    }}

    @PostMapping
    public ResponseEntity<{entity_name}Response> create{entity_name}(
        @Valid @RequestBody {entity_name}CreateRequest request
    ) {{
        {entity_name}Response {entity_var} = {entity_var}Service.create{entity_name}(request);
        return ResponseEntity.status(HttpStatus.CREATED).body({entity_var});
    }}

    @PutMapping("/{{id}}")
    public ResponseEntity<{entity_name}Response> update{entity_name}(
        @PathVariable Long id,
        @Valid @RequestBody {entity_name}CreateRequest request
    ) {{
        {entity_name}Response {entity_var} = {entity_var}Service.update{entity_name}(id, request);
        return ResponseEntity.ok({entity_var});
    }}

    @DeleteMapping("/{{id}}")
    public ResponseEntity<Void> delete{entity_name}(@PathVariable Long id) {{
        {entity_var}Service.delete{entity_name}(id);
        return ResponseEntity.noContent().build();
    }}
}}
'''

    file_path = output_dir / 'controller' / f'{entity_name}Controller.java'
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content)
    print(f'✓ Created: {file_path}')


def create_exception(entity_name, package_name, output_dir):
    """Custom Exception 생성"""
    content = f'''package {package_name}.exception;

public class {entity_name}NotFoundException extends RuntimeException {{

    public {entity_name}NotFoundException(Long id) {{
        super("{entity_name} not found with id: " + id);
    }}
}}
'''

    file_path = output_dir / 'exception' / f'{entity_name}NotFoundException.java'
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content)
    print(f'✓ Created: {file_path}')


def main():
    if len(sys.argv) != 3:
        print("Usage: python generate_api_scaffold.py <entity_name> <package_name>")
        print("Example: python generate_api_scaffold.py Product com.example.backend")
        sys.exit(1)

    entity_name = sys.argv[1]
    package_name = sys.argv[2]

    # 출력 디렉토리 설정
    package_path = package_name.replace('.', '/')
    output_dir = Path('src/main/java') / package_path

    print(f'\n🚀 Generating API scaffold for {entity_name}...\n')

    # 각 레이어 생성
    create_entity(entity_name, package_name, output_dir)
    create_repository(entity_name, package_name, output_dir)
    create_request_dto(entity_name, package_name, output_dir)
    create_response_dto(entity_name, package_name, output_dir)
    create_service(entity_name, package_name, output_dir)
    create_controller(entity_name, package_name, output_dir)
    create_exception(entity_name, package_name, output_dir)

    print(f'\n✅ API scaffold for {entity_name} generated successfully!')
    print(f'\nGenerated files:')
    print(f'  - Entity: domain/{entity_name}.java')
    print(f'  - Repository: repository/{entity_name}Repository.java')
    print(f'  - Request DTO: dto/request/{entity_name}CreateRequest.java')
    print(f'  - Response DTO: dto/response/{entity_name}Response.java')
    print(f'  - Service: service/{entity_name}Service.java')
    print(f'  - Controller: controller/{entity_name}Controller.java')
    print(f'  - Exception: exception/{entity_name}NotFoundException.java')


if __name__ == '__main__':
    main()
