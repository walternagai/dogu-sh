#!/usr/bin/env python3
"""
Script para gerar projetos de teste pedagógicos organizados por linguagem de programação.
Cria uma estrutura completa de projetos com código funcional, documentação e arquivos de build.

Autor: Sistema de Testes Pedagógicos
Versão: 4.0 - Projetos Corrigidos por Linguagem
"""

import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple

# Diretório base para os projetos de teste
BASE_DIR = Path("./testes_pedagogicos_lab_por_linguagem")

# Definição dos projetos organizados por linguagem
PROJECTS = {
    "C": {
        "01_hello_world": {
            "descricao": "Programa básico para validar compilação GCC",
            "files": {
                "main.c": """#include <stdio.h>
#include <stdlib.h>

/**
 * Programa de teste básico em C
 * Valida: compilação GCC, execução, saída padrão
 */
int main(void) {
    printf("=== Teste C - Hello World ===\\n");
    printf("Status: Ambiente configurado com sucesso!\\n");
    return EXIT_SUCCESS;
}
""",
                "README.md": """# Teste C - Hello World


**Objetivo:** Validar ambiente básico de compilação C

## Compilação
```bash
gcc -Wall -Wextra -o hello main.c
./hello
```

## Usando Makefile
```bash
make
make run
make clean
```

## Validação
- [ ] Compilação sem warnings
- [ ] Execução bem-sucedida
- [ ] Mensagem exibida corretamente
""",
                "Makefile": """CC = gcc
CFLAGS = -Wall -Wextra -std=c11
TARGET = hello

all: $(TARGET)

$(TARGET): main.c
\t$(CC) $(CFLAGS) -o $(TARGET) main.c

clean:
\trm -f $(TARGET)

run: $(TARGET)
\t./$(TARGET)
"""
            }
        },
        "03_ponteiros_alocacao": {
            "descricao": "Ponteiros, alocação dinâmica e arrays dinâmicos",
            "files": {
                "ponteiros.c": """#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * Teste de Ponteiros e Alocação Dinâmica em C
 * Valida: aritmética de ponteiros, malloc/free, realloc
 */

void imprimir_array(int *arr, int n, const char *titulo) {
    printf("%s: [", titulo);
    for (int i = 0; i < n; i++) {
        printf("%d%s", arr[i], i < n - 1 ? ", " : "");
    }
    printf("]\\n");
}

int *criar_array(int n) {
    int *arr = (int *)malloc(n * sizeof(int));
    if (!arr) {
        fprintf(stderr, "Erro: malloc falhou!\\n");
        exit(EXIT_FAILURE);
    }
    for (int i = 0; i < n; i++) {
        arr[i] = (i + 1) * 10;
    }
    return arr;
}

int *expandir_array(int *arr, int n_atual, int n_novo) {
    int *novo = (int *)realloc(arr, n_novo * sizeof(int));
    if (!novo) {
        fprintf(stderr, "Erro: realloc falhou!\\n");
        free(arr);
        exit(EXIT_FAILURE);
    }
    for (int i = n_atual; i < n_novo; i++) {
        novo[i] = (i + 1) * 10;
    }
    return novo;
}

void trocar(int *a, int *b) {
    int tmp = *a;
    *a = *b;
    *b = tmp;
}

int main(void) {
    printf("=== Teste de Ponteiros e Alocação Dinâmica ===\\n");
    printf("\\n\\n");

    /* --- Aritmética de ponteiros --- */
    printf("--- Aritmética de Ponteiros ---\\n");
    int valores[5] = {10, 20, 30, 40, 50};
    int *p = valores;
    for (int i = 0; i < 5; i++) {
        printf("  valores[%d] = %d  (endereço: %p)\\n", i, *(p + i), (void *)(p + i));
    }

    /* --- Troca via ponteiro --- */
    printf("\\n--- Troca via Ponteiro ---\\n");
    int x = 100, y = 200;
    printf("Antes:  x=%d, y=%d\\n", x, y);
    trocar(&x, &y);
    printf("Depois: x=%d, y=%d\\n", x, y);

    /* --- malloc e free --- */
    printf("\\n--- malloc / free ---\\n");
    int n = 5;
    int *arr = criar_array(n);
    imprimir_array(arr, n, "Array criado");

    /* --- realloc --- */
    printf("\\n--- realloc ---\\n");
    arr = expandir_array(arr, n, 8);
    imprimir_array(arr, 8, "Array expandido");
    free(arr);
    arr = NULL;
    printf("Memória liberada com sucesso.\\n");

    /* --- String dinâmica --- */
    printf("\\n--- String Dinâmica ---\\n");
    const char *msg = "Ponteiros em C!";
    char *copia = (char *)malloc((strlen(msg) + 1) * sizeof(char));
    if (!copia) { perror("malloc"); return EXIT_FAILURE; }
    strcpy(copia, msg);
    printf("Original: %s\\n", msg);
    printf("Cópia:    %s\\n", copia);
    free(copia);

    printf("\\n✓ Testes de ponteiros concluídos com sucesso!\\n");
    return EXIT_SUCCESS;
}
""",
                "README.md": """# Teste C - Ponteiros e Alocação Dinâmica


**Objetivo:** Validar aritmética de ponteiros, malloc, realloc e free

## Compilação
```bash
gcc -Wall -Wextra -std=c11 -o ponteiros ponteiros.c
./ponteiros
```

## Usando Makefile
```bash
make
make run
make valgrind   # verificar vazamentos de memória
```

## Conceitos testados
- Aritmética de ponteiros
- Passagem por referência
- `malloc`, `realloc`, `free`
- Strings dinâmicas
- Boas práticas (NULL após free)

## Validação
- [ ] Compilação sem warnings
- [ ] Nenhum vazamento de memória (valgrind)
- [ ] Todas as operações corretas
""",
                "Makefile": """CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -g
TARGET = ponteiros

all: $(TARGET)

$(TARGET): ponteiros.c
\t$(CC) $(CFLAGS) -o $(TARGET) ponteiros.c

clean:
\trm -f $(TARGET)

run: $(TARGET)
\t./$(TARGET)

valgrind: $(TARGET)
\tvalgrind --leak-check=full --error-exitcode=1 ./$(TARGET)
"""
            }
        },
        "04_arquivos_io": {
            "descricao": "Leitura e escrita de arquivos texto e binário",
            "files": {
                "arquivos.c": """#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * Teste de I/O de Arquivos em C
 * Valida: fopen, fclose, fgets, fprintf, fwrite, fread
 */

#define NOME_ARQUIVO "dados_teste.txt"
#define NOME_BIN     "dados_teste.bin"
#define MAX_LINHA    256

typedef struct {
    int id;
    char nome[50];
    float nota;
} Aluno;

void escrever_arquivo_texto() {
    printf("--- Escrita em Arquivo Texto ---\\n");
    FILE *f = fopen(NOME_ARQUIVO, "w");
    if (!f) { perror("fopen"); exit(EXIT_FAILURE); }

    fprintf(f, "# Dados dos Alunos\\n");
    fprintf(f, "%-4s %-20s %s\\n", "ID", "Nome", "Nota");
    fprintf(f, "1    Ana Silva            8.5\\n");
    fprintf(f, "2    Bruno Costa          7.0\\n");
    fprintf(f, "3    Carla Mendes         9.5\\n");

    fclose(f);
    printf("Arquivo '%s' criado.\\n", NOME_ARQUIVO);
}

void ler_arquivo_texto() {
    printf("\\n--- Leitura de Arquivo Texto ---\\n");
    FILE *f = fopen(NOME_ARQUIVO, "r");
    if (!f) { perror("fopen"); exit(EXIT_FAILURE); }

    char linha[MAX_LINHA];
    int linhas = 0;
    while (fgets(linha, sizeof(linha), f)) {
        linha[strcspn(linha, "\\n")] = '\\0';
        printf("  %s\\n", linha);
        linhas++;
    }
    fclose(f);
    printf("Total de linhas lidas: %d\\n", linhas);
}

void escrever_arquivo_binario() {
    printf("\\n--- Escrita em Arquivo Binário ---\\n");
    Aluno alunos[3] = {
        {1, "Ana Silva",    8.5f},
        {2, "Bruno Costa",  7.0f},
        {3, "Carla Mendes", 9.5f}
    };

    FILE *f = fopen(NOME_BIN, "wb");
    if (!f) { perror("fopen"); exit(EXIT_FAILURE); }
    size_t escritos = fwrite(alunos, sizeof(Aluno), 3, f);
    fclose(f);
    printf("%zu registros escritos em '%s'.\\n", escritos, NOME_BIN);
}

void ler_arquivo_binario() {
    printf("\\n--- Leitura de Arquivo Binário ---\\n");
    FILE *f = fopen(NOME_BIN, "rb");
    if (!f) { perror("fopen"); exit(EXIT_FAILURE); }

    Aluno aluno;
    while (fread(&aluno, sizeof(Aluno), 1, f) == 1) {
        printf("  ID: %d | %-20s | Nota: %.1f\\n",
               aluno.id, aluno.nome, aluno.nota);
    }
    fclose(f);
}

int main(void) {
    printf("=== Teste de I/O de Arquivos em C ===\\n");
    printf("\\n");

    escrever_arquivo_texto();
    ler_arquivo_texto();
    escrever_arquivo_binario();
    ler_arquivo_binario();

    /* Limpeza */
    remove(NOME_ARQUIVO);
    remove(NOME_BIN);
    printf("\\n✓ Arquivos de teste removidos.\\n");
    printf("✓ Testes de I/O de arquivos concluídos!\\n");
    return EXIT_SUCCESS;
}
""",
                "README.md": """# Teste C - I/O de Arquivos


**Objetivo:** Validar leitura e escrita de arquivos texto e binário

## Compilação
```bash
gcc -Wall -Wextra -std=c11 -o arquivos arquivos.c
./arquivos
```

## Usando Makefile
```bash
make
make run
```

## Conceitos testados
- `fopen`, `fclose`, `fgets`, `fprintf`
- Arquivo texto (modo `"r"` / `"w"`)
- Arquivo binário (`"rb"` / `"wb"`) com `fread`/`fwrite`
- Struct como unidade de persistência
- Remoção de `\\n` com `strcspn`

## Validação
- [ ] Arquivo texto criado e lido corretamente
- [ ] Arquivo binário escrito e lido corretamente
- [ ] Dados conferem entre escrita e leitura
""",
                "Makefile": """CC = gcc
CFLAGS = -Wall -Wextra -std=c11
TARGET = arquivos

all: $(TARGET)

$(TARGET): arquivos.c
\t$(CC) $(CFLAGS) -o $(TARGET) arquivos.c

clean:
\trm -f $(TARGET) dados_teste.txt dados_teste.bin

run: $(TARGET)
\t./$(TARGET)
"""
            }
        },
        "02_funcoes_modularizacao": {
            "descricao": "Teste de funções, modularização e biblioteca matemática",
            "files": {
                "funcoes.c": """#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/**
 * Teste de funções em C
 * Valida: modularização, passagem de parâmetros, bibliotecas matemáticas
 */

// Protótipos
int soma(int a, int b);
int subtracao(int a, int b);
double media(int valores[], int tamanho);
void imprimir_resultado(const char* operacao, double resultado);

int soma(int a, int b) {
    return a + b;
}

int subtracao(int a, int b) {
    return a - b;
}

double media(int valores[], int tamanho) {
    if (tamanho == 0) return 0.0;
    int soma_total = 0;
    for (int i = 0; i < tamanho; i++) {
        soma_total += valores[i];
    }
    return (double)soma_total / tamanho;
}

void imprimir_resultado(const char* operacao, double resultado) {
    printf("%-15s: %.2f\\n", operacao, resultado);
}

int main(void) {
    printf("=== Teste de Funções C ===\\n");
    printf("\\n\\n");
    
    // Testes de operações
    int a = 10, b = 3;
    printf("Valores: a = %d, b = %d\\n\\n", a, b);
    
    imprimir_resultado("Soma", soma(a, b));
    imprimir_resultado("Subtração", subtracao(a, b));
    imprimir_resultado("Potência", pow(a, b));
    
    // Teste de array e média
    int notas[] = {7, 8, 9, 6, 10};
    int n = sizeof(notas) / sizeof(notas[0]);
    imprimir_resultado("Média", media(notas, n));
    
    printf("\\nStatus: Funções testadas com sucesso!\\n");
    return EXIT_SUCCESS;
}
""",
                "README.md": """# Teste C - Funções e Modularização


**Objetivo:** Validar modularização e uso de bibliotecas

## Compilação
```bash
gcc -Wall -Wextra -o funcoes funcoes.c -lm
./funcoes
```

## Usando Makefile
```bash
make
make run
```

## Conceitos testados
- Protótipos de funções
- Passagem de parâmetros
- Arrays como parâmetros
- Biblioteca matemática (math.h)
- Formatação de saída

## Validação
- [ ] Compilação com -lm (math library)
- [ ] Todas as operações corretas
- [ ] Modularização adequada
""",
                "Makefile": """CC = gcc
CFLAGS = -Wall -Wextra -std=c11
LDFLAGS = -lm
TARGET = funcoes

all: $(TARGET)

$(TARGET): funcoes.c
\t$(CC) $(CFLAGS) -o $(TARGET) funcoes.c $(LDFLAGS)

clean:
\trm -f $(TARGET)

run: $(TARGET)
\t./$(TARGET)
"""
            }
        }
    },
    
    "CPP": {
        "02_classes_heranca": {
            "descricao": "Classes, herança, polimorfismo e métodos virtuais em C++",
            "files": {
                "oo.cpp": """#include <iostream>
#include <vector>
#include <memory>
#include <string>
#include <iomanip>
#include <cmath>

/**
 * Teste C++ - Classes, Herança e Polimorfismo
 * Valida: OO em C++17, virtual, override, smart pointers
 */

class Forma {
protected:
    std::string nome;
    std::string cor;
public:
    Forma(const std::string& nome, const std::string& cor)
        : nome(nome), cor(cor) {}

    virtual double area() const = 0;
    virtual double perimetro() const = 0;
    virtual void descrever() const {
        std::cout << std::fixed << std::setprecision(2);
        std::cout << "Forma:     " << nome << " (" << cor << ")\\n";
        std::cout << "Área:      " << area() << "\\n";
        std::cout << "Perímetro: " << perimetro() << "\\n";
    }
    virtual ~Forma() = default;
};

class Circulo : public Forma {
    double raio;
    static constexpr double PI = 3.14159265358979;
public:
    Circulo(double raio, const std::string& cor = "azul")
        : Forma("Círculo", cor), raio(raio) {}

    double area() const override { return PI * raio * raio; }
    double perimetro() const override { return 2 * PI * raio; }
    void descrever() const override {
        std::cout << "  [Círculo] raio=" << raio << "\\n";
        Forma::descrever();
    }
};

class Retangulo : public Forma {
    double largura, altura;
public:
    Retangulo(double l, double h, const std::string& cor = "verde")
        : Forma("Retângulo", cor), largura(l), altura(h) {}

    double area() const override { return largura * altura; }
    double perimetro() const override { return 2 * (largura + altura); }
    void descrever() const override {
        std::cout << "  [Retângulo] " << largura << "x" << altura << "\\n";
        Forma::descrever();
    }
};

class Triangulo : public Forma {
    double a, b, c;
public:
    Triangulo(double a, double b, double c, const std::string& cor = "vermelho")
        : Forma("Triângulo", cor), a(a), b(b), c(c) {}

    double area() const override {
        double s = (a + b + c) / 2.0;
        return std::sqrt(s * (s - a) * (s - b) * (s - c));
    }
    double perimetro() const override { return a + b + c; }
    void descrever() const override {
        std::cout << "  [Triângulo] lados=" << a << "," << b << "," << c << "\\n";
        Forma::descrever();
    }
};

int main() {
    std::cout << "=== Teste C++ - Classes e Polimorfismo ===\\n\\n";

    std::vector<std::unique_ptr<Forma>> formas;
    formas.push_back(std::make_unique<Circulo>(5.0));
    formas.push_back(std::make_unique<Retangulo>(4.0, 6.0));
    formas.push_back(std::make_unique<Triangulo>(3.0, 4.0, 5.0));

    double area_total = 0.0;
    for (const auto& f : formas) {
        std::cout << "─────────────────────────\\n";
        f->descrever();
        area_total += f->area();
    }

    std::cout << "─────────────────────────\\n";
    std::cout << std::fixed << std::setprecision(2);
    std::cout << "Área total de todas as formas: " << area_total << "\\n";
    std::cout << "\\n✓ Polimorfismo e smart pointers funcionando!\\n";
    return 0;
}
""",
                "README.md": """# Teste C++ - Classes, Herança e Polimorfismo


**Objetivo:** Validar OO em C++17 com smart pointers

## Compilação
```bash
g++ -std=c++17 -Wall -Wextra -o oo oo.cpp
./oo
```

## Usando Makefile
```bash
make
make run
```

## Conceitos testados
- Herança pública
- Métodos virtuais puros (classe abstrata)
- `override` e `final`
- `unique_ptr` (RAII)
- Polimorfismo em tempo de execução
- `constexpr`

## Validação
- [ ] Compilação C++17 sem warnings
- [ ] Polimorfismo funcionando corretamente
- [ ] Sem vazamentos (smart pointers)
""",
                "Makefile": """CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra
TARGET = oo

all: $(TARGET)

$(TARGET): oo.cpp
\t$(CXX) $(CXXFLAGS) -o $(TARGET) oo.cpp

clean:
\trm -f $(TARGET)

run: $(TARGET)
\t./$(TARGET)
"""
            }
        },
        "03_excecoes": {
            "descricao": "Tratamento de exceções, exceções customizadas e RAII",
            "files": {
                "excecoes.cpp": """#include <iostream>
#include <stdexcept>
#include <vector>
#include <string>
#include <fstream>

/**
 * Teste C++ - Exceções e RAII
 * Valida: try/catch/throw, exceções customizadas, RAII com RAII guard
 */

// Exceção customizada
class NotaInvalidaException : public std::runtime_error {
    double nota;
public:
    explicit NotaInvalidaException(double nota)
        : std::runtime_error("Nota fora do intervalo [0, 10]: " + std::to_string(nota)),
          nota(nota) {}
    double getNota() const { return nota; }
};

class DivisaoPorZeroException : public std::runtime_error {
public:
    DivisaoPorZeroException()
        : std::runtime_error("Divisão por zero não é permitida") {}
};

// Função que pode lançar exceção de domínio
double dividir(double a, double b) {
    if (b == 0.0) throw DivisaoPorZeroException();
    return a / b;
}

void validar_nota(double nota) {
    if (nota < 0.0 || nota > 10.0) throw NotaInvalidaException(nota);
    std::cout << "  Nota válida: " << nota << "\\n";
}

// RAII: recurso garantidamente liberado
class ArquivoTemporario {
    std::string nome;
    std::ofstream arquivo;
public:
    explicit ArquivoTemporario(const std::string& nome) : nome(nome), arquivo(nome) {
        if (!arquivo.is_open()) throw std::ios_base::failure("Não foi possível criar " + nome);
        arquivo << "Conteúdo de teste RAII\\n";
        std::cout << "  Arquivo '" << nome << "' criado (RAII)\\n";
    }
    ~ArquivoTemporario() {
        arquivo.close();
        std::remove(nome.c_str());
        std::cout << "  Arquivo '" << nome << "' removido (RAII destructor)\\n";
    }
};

int main() {
    std::cout << "=== Teste C++ - Exceções e RAII ===\\n\\n";

    // Teste 1: exceção da STL
    std::cout << "--- Exceção STL (out_of_range) ---\\n";
    try {
        std::vector<int> v = {1, 2, 3};
        std::cout << "  v.at(10) = " << v.at(10) << "\\n";
    } catch (const std::out_of_range& e) {
        std::cout << "  Capturado: " << e.what() << "\\n";
    }

    // Teste 2: exceção customizada de nota
    std::cout << "\\n--- Exceção Customizada (NotaInvalida) ---\\n";
    double notas[] = {8.5, -1.0, 11.0, 7.0};
    for (double n : notas) {
        try {
            validar_nota(n);
        } catch (const NotaInvalidaException& e) {
            std::cout << "  Erro: " << e.what() << "\\n";
        }
    }

    // Teste 3: divisão por zero
    std::cout << "\\n--- Exceção de Divisão por Zero ---\\n";
    try {
        std::cout << "  10 / 2 = " << dividir(10, 2) << "\\n";
        std::cout << "  10 / 0 = " << dividir(10, 0) << "\\n";
    } catch (const DivisaoPorZeroException& e) {
        std::cout << "  Capturado: " << e.what() << "\\n";
    }

    // Teste 4: RAII
    std::cout << "\\n--- RAII (gerenciamento automático de recursos) ---\\n";
    {
        ArquivoTemporario tmp("raii_teste.txt");
        std::cout << "  (usando o recurso...)\\n";
    }   // destrutor chamado automaticamente aqui

    std::cout << "\\n✓ Testes de exceções e RAII concluídos com sucesso!\\n";
    return 0;
}
""",
                "README.md": """# Teste C++ - Exceções e RAII


**Objetivo:** Validar tratamento de exceções e gerenciamento automático de recursos

## Compilação
```bash
g++ -std=c++17 -Wall -Wextra -o excecoes excecoes.cpp
./excecoes
```

## Conceitos testados
- `try` / `catch` / `throw`
- Exceções da STL (`std::out_of_range`, `std::runtime_error`)
- Herança de exceções customizadas
- RAII (Resource Acquisition Is Initialization)
- Destrutor automático garantindo limpeza

## Validação
- [ ] Todas as exceções capturadas corretamente
- [ ] RAII: recurso criado e destruído automaticamente
- [ ] Nenhuma exceção não tratada
""",
                "Makefile": """CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra
TARGET = excecoes

all: $(TARGET)

$(TARGET): excecoes.cpp
\t$(CXX) $(CXXFLAGS) -o $(TARGET) excecoes.cpp

clean:
\trm -f $(TARGET) raii_teste.txt

run: $(TARGET)
\t./$(TARGET)
"""
            }
        },
        "01_stl_templates": {
            "descricao": "Teste de STL, templates e C++17",
            "files": {
                "main.cpp": """#include <iostream>
#include <vector>
#include <numeric>
#include <iomanip>

/**
 * Programa de teste C++
 * Valida: compilação g++, STL, templates, cálculos
 */

template<typename T>
double calcular_media(const std::vector<T>& valores) {
    if (valores.empty()) return 0.0;
    T soma = std::accumulate(valores.begin(), valores.end(), T(0));
    return static_cast<double>(soma) / valores.size();
}

int main() {
    std::cout << "=== Teste C++ - STL e Templates ===" << std::endl;
    std::cout << std::endl;
    
    std::vector<int> notas = {5, 7, 9, 8, 6};
    double media = calcular_media(notas);
    
    std::cout << std::fixed << std::setprecision(2);
    std::cout << "Notas: ";
    for (const auto& nota : notas) {
        std::cout << nota << " ";
    }
    std::cout << "\\nMédia: " << media << std::endl;
    std::cout << "\\nStatus: Ambiente C++ configurado!" << std::endl;
    
    return 0;
}
""",
                "README.md": """# Teste C++ - STL e Templates


**Objetivo:** Validar C++17 e bibliotecas padrão

## Compilação
```bash
g++ -std=c++17 -Wall -Wextra -o media main.cpp
./media
```

## Usando Makefile
```bash
make
make run
```

## Recursos testados
- Templates
- STL (vector, numeric)
- Manipuladores de I/O
- C++17 features

## Validação
- [ ] Compilação C++17
- [ ] Uso correto da STL
- [ ] Cálculo preciso
""",
                "Makefile": """CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra
TARGET = media

all: $(TARGET)

$(TARGET): main.cpp
\t$(CXX) $(CXXFLAGS) -o $(TARGET) main.cpp

clean:
\trm -f $(TARGET)

run: $(TARGET)
\t./$(TARGET)
"""
            }
        }
    },
    
    "Python": {
        "01_basico": {
            "descricao": "Script básico para validar Python 3",
            "files": {
                "script.py": """#!/usr/bin/env python3
\"\"\"
Script de teste básico em Python
Valida: interpretador Python 3, bibliotecas padrão, execução
\"\"\"

import sys
import platform

def main():
    print("=== Teste Python Básico ===")
    print(f"Versão Python: {sys.version}")
    print(f"Plataforma: {platform.system()} {platform.release()}")
    print("Status: Ambiente Python configurado!")
    
    # Teste de estruturas básicas
    dados = [1, 2, 3, 4, 5]
    media = sum(dados) / len(dados)
    print(f"\\nTeste de cálculo - Média: {media:.2f}")

if __name__ == "__main__":
    main()
""",
                "README.md": """# Teste Python Básico


**Objetivo:** Validar instalação Python 3

## Execução
```bash
python3 script.py
# ou
chmod +x script.py
./script.py
```

## Validação
- [ ] Python 3.8+ instalado
- [ ] Execução sem erros
- [ ] Saída formatada corretamente
"""
            }
        },
        "02_graficos_turtle": {
            "descricao": "Teste de interface gráfica com Turtle",
            "files": {
                "turtle_test.py": """#!/usr/bin/env python3
\"\"\"
Teste de gráficos Turtle - Desenho de polígono
Valida: tkinter, turtle, interface gráfica
\"\"\"

import turtle
import sys

def desenhar_poligono(lados=6, tamanho=100):
    \"\"\"Desenha um polígono regular\"\"\"
    janela = turtle.Screen()
    janela.title("Teste Turtle - Prof. Eduardo")
    janela.bgcolor("white")
    
    t = turtle.Turtle()
    t.speed(2)
    t.color("blue")
    t.pensize(2)
    
    angulo = 360 / lados
    
    for _ in range(lados):
        t.forward(tamanho)
        t.right(angulo)
    
    t.hideturtle()
    
    print("=== Teste Turtle Graphics ===")
    print(f"Polígono de {lados} lados desenhado!")
    print("Feche a janela para continuar...")
    
    try:
        turtle.done()
    except turtle.Terminator:
        print("Janela fechada pelo usuário")

if __name__ == "__main__":
    try:
        desenhar_poligono(6, 100)
    except Exception as e:
        print(f"Erro: {e}", file=sys.stderr)
        sys.exit(1)
""",
                "README.md": """# Teste Python - Turtle Graphics


**Objetivo:** Validar interface gráfica Tkinter/Turtle

## Execução
```bash
python3 turtle_test.py
```

## Validação
- [ ] Tkinter disponível
- [ ] Janela gráfica abre
- [ ] Polígono desenhado corretamente
- [ ] Sem erros de importação
"""
            }
        },
        "03_pygame": {
            "descricao": "Teste de biblioteca Pygame",
            "files": {
                "pygame_test.py": """#!/usr/bin/env python3
\"\"\"
Teste básico Pygame - Janela interativa
Valida: pygame, renderização, eventos
\"\"\"

import pygame
import sys

def main():
    print("=== Teste Pygame ===")
    print("Iniciando...")

    # Inicialização
    pygame.init()
    
    # Configuração da janela
    LARGURA, ALTURA = 640, 480
    tela = pygame.display.set_mode((LARGURA, ALTURA))
    pygame.display.set_caption("Teste Pygame")
    
    # Cores
    BRANCO = (255, 255, 255)
    AZUL = (0, 100, 200)
    VERDE = (0, 200, 0)
    
    # Relógio para controlar FPS
    relogio = pygame.time.Clock()
    
    # Posição do círculo
    pos_x, pos_y = LARGURA // 2, ALTURA // 2
    velocidade = 5
    
    rodando = True
    print("Janela aberta. Use as setas para mover o círculo.")
    print("Pressione ESC ou feche a janela para sair.")
    
    while rodando:
        for evento in pygame.event.get():
            if evento.type == pygame.QUIT:
                rodando = False
            elif evento.type == pygame.KEYDOWN:
                if evento.key == pygame.K_ESCAPE:
                    rodando = False
        
        # Controle de movimento
        teclas = pygame.key.get_pressed()
        if teclas[pygame.K_LEFT] and pos_x > 20:
            pos_x -= velocidade
        if teclas[pygame.K_RIGHT] and pos_x < LARGURA - 20:
            pos_x += velocidade
        if teclas[pygame.K_UP] and pos_y > 20:
            pos_y -= velocidade
        if teclas[pygame.K_DOWN] and pos_y < ALTURA - 20:
            pos_y += velocidade
        
        # Renderização
        tela.fill(BRANCO)
        pygame.draw.circle(tela, AZUL, (pos_x, pos_y), 20)
        
        # Texto de instruções
        fonte = pygame.font.Font(None, 36)
        texto = fonte.render("Use as setas do teclado", True, VERDE)
        tela.blit(texto, (150, 20))
        
        pygame.display.flip()
        relogio.tick(60)  # 60 FPS
    
    pygame.quit()
    print("Teste concluído com sucesso!")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Erro: {e}", file=sys.stderr)
        sys.exit(1)
""",
                "README.md": """# Teste Python - Pygame


**Objetivo:** Validar biblioteca Pygame

## Dependências
```bash
pip install pygame
```

## Execução
```bash
python3 pygame_test.py
```

## Validação
- [ ] Pygame instalado
- [ ] Janela gráfica funciona
- [ ] Eventos de teclado detectados
- [ ] Renderização a 60 FPS
"""
            }
        },
        "05_fastapi_rest": {
            "descricao": "API REST com FastAPI, Pydantic e uvicorn",
            "files": {
                "main.py": """#!/usr/bin/env python3
\"\"\"
API REST com FastAPI
Valida: FastAPI, Pydantic, uvicorn, endpoints REST
\"\"\"

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
import uvicorn

app = FastAPI(
    title="API de Alunos - Teste FastAPI",
    description="Laboratório: validação do ambiente FastAPI",
    version="1.0.0"
)

# ── Modelos Pydantic ──────────────────────────────────────────────
class AlunoCreate(BaseModel):
    nome: str = Field(..., min_length=2, max_length=100, example="João Silva")
    email: str = Field(..., example="joao@email.com")
    nota: float = Field(..., ge=0.0, le=10.0, example=8.5)

class Aluno(AlunoCreate):
    id: int
    criado_em: datetime = Field(default_factory=datetime.now)

# ── Banco em memória ──────────────────────────────────────────────
db: List[Aluno] = [
    Aluno(id=1, nome="Ana Lima",     email="ana@email.com",   nota=9.0, criado_em=datetime.now()),
    Aluno(id=2, nome="Bruno Melo",   email="bruno@email.com", nota=7.5, criado_em=datetime.now()),
    Aluno(id=3, nome="Carla Nunes",  email="carla@email.com", nota=8.0, criado_em=datetime.now()),
]
prox_id = 4

# ── Endpoints ─────────────────────────────────────────────────────
@app.get("/", tags=["Info"])
def raiz():
    return {
        "mensagem": "API FastAPI funcionando!",
        "docs": "/docs",
        "total_alunos": len(db)
    }

@app.get("/alunos", response_model=List[Aluno], tags=["Alunos"])
def listar_alunos(nota_minima: Optional[float] = None):
    \"\"\"Lista todos os alunos, com filtro opcional por nota mínima.\"\"\"
    resultado = db
    if nota_minima is not None:
        resultado = [a for a in db if a.nota >= nota_minima]
    return resultado

@app.get("/alunos/{aluno_id}", response_model=Aluno, tags=["Alunos"])
def obter_aluno(aluno_id: int):
    aluno = next((a for a in db if a.id == aluno_id), None)
    if not aluno:
        raise HTTPException(status_code=404, detail=f"Aluno {aluno_id} não encontrado")
    return aluno

@app.post("/alunos", response_model=Aluno, status_code=201, tags=["Alunos"])
def criar_aluno(dados: AlunoCreate):
    global prox_id
    novo = Aluno(id=prox_id, **dados.dict())
    db.append(novo)
    prox_id += 1
    return novo

@app.get("/estatisticas", tags=["Info"])
def estatisticas():
    if not db:
        return {"total": 0}
    notas = [a.nota for a in db]
    return {
        "total_alunos": len(db),
        "media_notas": round(sum(notas) / len(notas), 2),
        "maior_nota":  max(notas),
        "menor_nota":  min(notas),
    }

# ── Execução direta ───────────────────────────────────────────────
if __name__ == "__main__":
    print("=== Teste FastAPI ===")
    print("Servidor: http://localhost:8000")
    print("Docs:     http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)
""",
                "requirements.txt": """fastapi>=0.110.0
uvicorn[standard]>=0.29.0
pydantic>=2.0.0
""",
                "README.md": """# Teste Python - FastAPI REST


**Objetivo:** Validar ambiente FastAPI, Pydantic e uvicorn

## Instalação
```bash
pip install -r requirements.txt
# ou
pip install fastapi uvicorn pydantic
```

## Execução
```bash
python3 main.py
# ou
uvicorn main:app --reload
```

## Teste
- Acesse: `http://localhost:8000`
- Swagger UI: `http://localhost:8000/docs`

## Endpoints
| Método | Rota | Descrição |
|--------|------|-----------|
| GET | / | Status da API |
| GET | /alunos | Listar alunos |
| GET | /alunos/{id} | Obter aluno |
| POST | /alunos | Criar aluno |
| GET | /estatisticas | Estatísticas |

## Validação
- [ ] FastAPI instalado
- [ ] Servidor inicia sem erros
- [ ] Docs Swagger acessível
- [ ] CRUD funcionando
- [ ] Validação Pydantic ativa
"""
            }
        },
        "06_ciencia_dados": {
            "descricao": "Análise de dados com NumPy, Pandas, Matplotlib e SciPy",
            "files": {
                "ciencia_dados.py": """#!/usr/bin/env python3
\"\"\"
Análise de Dados com NumPy, Pandas, Matplotlib e SciPy
Valida: bibliotecas científicas, análise estatística, visualização
\"\"\"

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats
import sys
import warnings
warnings.filterwarnings('ignore')

def secao(titulo):
    print(f"\\n{'='*55}")
    print(f"  {titulo}")
    print('='*55)

def teste_numpy():
    secao("NumPy")

    # Arrays e operações vetorizadas
    notas = np.array([7.5, 8.0, 6.5, 9.0, 8.5, 7.0, 9.5, 6.0, 8.0, 7.5])
    print(f"Notas:           {notas}")
    print(f"Média:           {np.mean(notas):.2f}")
    print(f"Desvio padrão:   {np.std(notas):.2f}")
    print(f"Mediana:         {np.median(notas):.2f}")
    print(f"Min / Max:       {notas.min():.1f} / {notas.max():.1f}")

    # Álgebra linear básica
    A = np.array([[2, 1], [5, 3]])
    b = np.array([8, 21])
    x = np.linalg.solve(A, b)
    print(f"\\nSistema Ax=b → x = {x}  (verificação: {np.allclose(A @ x, b)})")
    return notas

def teste_pandas(notas):
    secao("Pandas")

    df = pd.DataFrame({
        'Aluno':      ['Ana', 'Bruno', 'Carla', 'Diego', 'Elena',
                       'Fábio', 'Gabi', 'Hugo', 'Iris', 'João'],
        'Nota':       notas,
        'Frequencia': [90, 85, 78, 95, 88, 70, 92, 80, 88, 75],
        'Turma':      ['A','A','B','B','A','B','A','B','A','B']
    })

    print(df.to_string(index=False))
    print(f"\\n{df.describe().round(2)}")

    print("\\nMédia por turma:")
    print(df.groupby('Turma')['Nota'].agg(['mean','std','count']).round(2))

    aprovados = df[df['Nota'] >= 7.0]
    print(f"\\nAprovados (≥7.0): {len(aprovados)} de {len(df)}")
    return df

def teste_scipy(df):
    secao("SciPy - Estatística")

    turma_a = df[df['Turma'] == 'A']['Nota'].values
    turma_b = df[df['Turma'] == 'B']['Nota'].values

    stat, p = stats.ttest_ind(turma_a, turma_b)
    print(f"Teste t de Student entre Turma A e B:")
    print(f"  t = {stat:.4f},  p = {p:.4f}")
    print(f"  {'Diferença significativa (p<0.05)' if p < 0.05 else 'Sem diferença significativa'}")

    corr, p_corr = stats.pearsonr(df['Nota'], df['Frequencia'])
    print(f"\\nCorrelação Nota × Frequência: r = {corr:.4f} (p = {p_corr:.4f})")

def gerar_graficos(df):
    secao("Matplotlib - Geração de Gráficos")

    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    fig.suptitle('Análise de Desempenho - Lab Python', fontsize=14, fontweight='bold')

    # Gráfico 1: Barras de notas
    colors = ['#2196F3' if t == 'A' else '#FF9800' for t in df['Turma']]
    axes[0].bar(df['Aluno'], df['Nota'], color=colors)
    axes[0].axhline(y=7.0, color='red', linestyle='--', label='Mínimo (7.0)')
    axes[0].set_title('Notas por Aluno')
    axes[0].set_ylabel('Nota')
    axes[0].set_ylim(0, 11)
    axes[0].legend()
    axes[0].tick_params(axis='x', rotation=45)

    # Gráfico 2: Dispersão Nota × Frequência
    turma_cores = {'A': '#2196F3', 'B': '#FF9800'}
    for turma, grupo in df.groupby('Turma'):
        axes[1].scatter(grupo['Frequencia'], grupo['Nota'],
                        label=f'Turma {turma}', color=turma_cores[turma], s=80)
    axes[1].set_title('Nota × Frequência')
    axes[1].set_xlabel('Frequência (%)')
    axes[1].set_ylabel('Nota')
    axes[1].legend()

    plt.tight_layout()
    nome = 'analise_dados.png'
    plt.savefig(nome, dpi=100)
    print(f"Gráfico salvo em '{nome}'")
    plt.close()

def main():
    print("=== Teste Python - Ciência de Dados ===")
    print(f"Python: {sys.version.split()[0]}")
    print(f"NumPy:  {np.__version__}")
    print(f"Pandas: {pd.__version__}")

    notas  = teste_numpy()
    df     = teste_pandas(notas)
    teste_scipy(df)
    gerar_graficos(df)

    print("\\n✓ Bibliotecas científicas validadas com sucesso!")

if __name__ == "__main__":
    main()
""",
                "requirements.txt": """numpy>=1.24.0
pandas>=2.0.0
matplotlib>=3.7.0
scipy>=1.11.0
""",
                "README.md": """# Teste Python - Ciência de Dados


**Objetivo:** Validar NumPy, Pandas, Matplotlib e SciPy

## Instalação
```bash
pip install -r requirements.txt
```

## Execução
```bash
python3 ciencia_dados.py
```

## O que é testado
- **NumPy**: arrays, estatísticas, álgebra linear
- **Pandas**: DataFrame, groupby, describe, filtragem
- **SciPy**: teste t de Student, correlação de Pearson
- **Matplotlib**: gráficos de barra e dispersão salvos em PNG

## Arquivos gerados
- `analise_dados.png` - gráficos de análise

## Validação
- [ ] Todas as bibliotecas importadas
- [ ] Estatísticas calculadas corretamente
- [ ] Gráfico salvo sem erros
"""
            }
        },
        "04_jupyter_notebook": {
            "descricao": "Notebook com NumPy, Pandas e Matplotlib",
            "files": {
                "teste_notebook.ipynb": """{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
     "# Teste Jupyter Notebook\\n",
     "\\n",
     "**Objetivo:** Validar ambiente Jupyter e bibliotecas científicas"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "source": [
    "# Importações e verificação de ambiente\\n",
    "import sys\\n",
    "import numpy as np\\n",
    "import pandas as pd\\n",
    "import matplotlib.pyplot as plt\\n",
    "\\n",
    "print(f\\"Python: {sys.version}\\")\\n",
    "print(f\\"NumPy: {np.__version__}\\")\\n",
    "print(f\\"Pandas: {pd.__version__}\\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "source": [
    "# Teste com NumPy\\n",
    "dados = np.array([1, 2, 3, 4, 5])\\n",
    "print(f\\"Dados: {dados}\\")\\n",
    "print(f\\"Média: {np.mean(dados):.2f}\\")\\n",
    "print(f\\"Desvio padrão: {np.std(dados):.2f}\\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "source": [
    "# Teste com Pandas\\n",
    "df = pd.DataFrame({\\n",
    "    'Aluno': ['Ana', 'Bruno', 'Carlos', 'Diana', 'Eduardo'],\\n",
    "    'Nota': [8.5, 7.0, 9.5, 6.5, 8.0]\\n",
    "})\\n",
    "\\n",
    "print(\\"DataFrame de teste:\\")\\n",
    "print(df)\\n",
    "print(f\\"\\\\nMédia das notas: {df['Nota'].mean():.2f}\\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "source": [
    "# Teste com Matplotlib\\n",
    "plt.figure(figsize=(10, 6))\\n",
    "plt.bar(df['Aluno'], df['Nota'], color='skyblue')\\n",
    "plt.xlabel('Aluno')\\n",
    "plt.ylabel('Nota')\\n",
    "plt.title('Notas dos Alunos')\\n",
    "plt.ylim(0, 10)\\n",
    "plt.grid(axis='y', alpha=0.3)\\n",
    "plt.show()"
   ]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "## Validação\\n",
    "\\n",
    "- [x] Jupyter funcionando\\n",
    "- [x] NumPy instalado\\n",
    "- [x] Pandas instalado\\n",
    "- [x] Matplotlib funcionando\\n",
    "- [x] Gráficos renderizando"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.8.0"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
""",
                "README.md": """# Teste Python - Jupyter Notebook


**Objetivo:** Validar ambiente Jupyter com bibliotecas científicas

## Instalação
```bash
pip install jupyter numpy pandas matplotlib
```

## Execução
```bash
jupyter notebook teste_notebook.ipynb
```

## Validação
- [ ] Jupyter abre no navegador
- [ ] Todas as células executam
- [ ] Gráficos são exibidos
- [ ] Sem erros de importação
"""
            }
        }
    },
    
    "Java": {
        "03_colecoes_streams": {
            "descricao": "Collections Framework, Stream API e expressões lambda",
            "files": {
                "ColecoeStreams.java": """import java.util.*;
import java.util.stream.*;
import java.util.function.*;
import java.util.Map;

/**
 * Teste Java - Collections e Stream API

 * Valida: ArrayList, HashMap, Stream, lambda, Optional
 */

public class ColecoeStreams {

    record Aluno(String nome, String turma, double nota) {}

    public static void main(String[] args) {
        System.out.println("=== Teste Java - Collections e Streams ===");
        System.out.println();
        // ── ArrayList ───────────────────────────────────────────
        System.out.println("--- ArrayList ---");
        List<Aluno> alunos = new ArrayList<>(List.of(
            new Aluno("Ana Lima",    "A", 9.0),
            new Aluno("Bruno Melo",  "B", 6.5),
            new Aluno("Carla Nunes", "A", 8.0),
            new Aluno("Diego Faria", "B", 7.5),
            new Aluno("Elena Cruz",  "A", 5.0),
            new Aluno("Fábio Reis",  "B", 9.5)
        ));
        System.out.println("Total de alunos: " + alunos.size());

        // ── HashMap ─────────────────────────────────────────────
        System.out.println("\\n--- HashMap ---");
        Map<String, Double> mediaPorTurma = new HashMap<>();
        Map<String, List<Double>> notasPorTurma = new HashMap<>();

        for (Aluno a : alunos) {
            notasPorTurma.computeIfAbsent(a.turma(), k -> new ArrayList<>()).add(a.nota());
        }
        notasPorTurma.forEach((turma, notas) -> {
            double media = notas.stream().mapToDouble(Double::doubleValue).average().orElse(0);
            mediaPorTurma.put(turma, media);
            System.out.printf("  Turma %s → média: %.2f%n", turma, media);
        });

        // ── Streams básicos ─────────────────────────────────────
        System.out.println("\\n--- Stream API (filter, map, sorted) ---");

        List<String> aprovados = alunos.stream()
            .filter(a -> a.nota() >= 7.0)
            .sorted(Comparator.comparingDouble(Aluno::nota).reversed())
            .map(a -> String.format("%-15s %.1f", a.nome(), a.nota()))
            .collect(Collectors.toList());

        System.out.println("Aprovados (nota ≥ 7.0), ordenados:");
        aprovados.forEach(s -> System.out.println("  " + s));

        // ── Estatísticas ─────────────────────────────────────────
        System.out.println("\\n--- Estatísticas com Streams ---");
        DoubleSummaryStatistics stats = alunos.stream()
            .mapToDouble(Aluno::nota)
            .summaryStatistics();

        System.out.printf("  Count: %d%n",   stats.getCount());
        System.out.printf("  Soma:  %.1f%n", stats.getSum());
        System.out.printf("  Média: %.2f%n", stats.getAverage());
        System.out.printf("  Min:   %.1f%n", stats.getMin());
        System.out.printf("  Max:   %.1f%n", stats.getMax());

        // ── groupingBy ───────────────────────────────────────────
        System.out.println("\\n--- Collectors.groupingBy ---");
        Map<String, Long> contagemPorTurma = alunos.stream()
            .collect(Collectors.groupingBy(Aluno::turma, Collectors.counting()));
        contagemPorTurma.forEach((t, c) -> System.out.println("  Turma " + t + ": " + c + " alunos"));

        // ── Optional ─────────────────────────────────────────────
        System.out.println("\\n--- Optional ---");
        Optional<Aluno> melhor = alunos.stream()
            .max(Comparator.comparingDouble(Aluno::nota));
        melhor.ifPresent(a -> System.out.println("  Melhor aluno: " + a.nome() + " (" + a.nota() + ")"));

        System.out.println("\\n✓ Collections e Streams testados com sucesso!");
    }
}
""",
                "README.md": """# Teste Java - Collections e Stream API


**Objetivo:** Validar Collections Framework e Stream API com lambdas

## Compilação e Execução
```bash
javac ColecoeStreams.java
java ColecoeStreams
```

## Requer Java 16+ (records)
```bash
java -version  # deve ser 16 ou superior
```

## Conceitos testados
- `ArrayList`, `HashMap`
- `stream()` → `filter`, `map`, `sorted`, `collect`
- `Collectors.groupingBy`, `DoubleSummaryStatistics`
- Expressões lambda e method references
- `Optional`
- `record` (Java 16+)

## Validação
- [ ] Compilação sem warnings
- [ ] Filtragem e ordenação corretas
- [ ] Estatísticas corretas
- [ ] groupingBy funcionando
"""
            }
        },
        "04_jdbc_sqlite": {
            "descricao": "Acesso a banco de dados SQLite via JDBC",
            "files": {
                "JdbcSqlite.java": """import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Teste Java - JDBC com SQLite

 * Valida: JDBC API, SQLite, CRUD, PreparedStatement
 *
 * Dependência: sqlite-jdbc (https://github.com/xerial/sqlite-jdbc)
 * Download: wget https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.45.1.0/sqlite-jdbc-3.45.1.0.jar
 * Compilação: javac -cp sqlite-jdbc-*.jar JdbcSqlite.java
 * Execução:   java -cp .:sqlite-jdbc-*.jar JdbcSqlite
 */

public class JdbcSqlite {

    static final String URL = "jdbc:sqlite:alunos_teste.db";

    static void criarTabela(Connection conn) throws SQLException {
        String sql = "CREATE TABLE IF NOT EXISTS alunos (" +
                     "  id    INTEGER PRIMARY KEY AUTOINCREMENT," +
                     "  nome  TEXT    NOT NULL," +
                     "  email TEXT    UNIQUE NOT NULL," +
                     "  nota  REAL    NOT NULL" +
                     ")";
        try (Statement st = conn.createStatement()) {
            st.execute(sql);
            st.execute("DELETE FROM alunos");  // limpar execuções anteriores
        }
        System.out.println("✓ Tabela criada");
    }

    static void inserir(Connection conn, String nome, String email, double nota) throws SQLException {
        String sql = "INSERT INTO alunos (nome, email, nota) VALUES (?, ?, ?)";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, nome);
            ps.setString(2, email);
            ps.setDouble(3, nota);
            ps.executeUpdate();
        }
    }

    static List<String> listar(Connection conn) throws SQLException {
        List<String> resultado = new ArrayList<>();
        String sql = "SELECT id, nome, nota FROM alunos ORDER BY nota DESC";
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                resultado.add(String.format("  ID:%d %-20s %.1f",
                    rs.getInt("id"), rs.getString("nome"), rs.getDouble("nota")));
            }
        }
        return resultado;
    }

    static void estatisticas(Connection conn) throws SQLException {
        String sql = "SELECT COUNT(*) as total, AVG(nota) as media, MAX(nota) as max, MIN(nota) as min FROM alunos";
        try (Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            if (rs.next()) {
                System.out.printf("  Total:  %d%n",   rs.getInt("total"));
                System.out.printf("  Média:  %.2f%n", rs.getDouble("media"));
                System.out.printf("  Máx:    %.1f%n", rs.getDouble("max"));
                System.out.printf("  Mín:    %.1f%n", rs.getDouble("min"));
            }
        }
    }

    public static void main(String[] args) {
        System.out.println("=== Teste Java - JDBC + SQLite ===");
        System.out.println();
        try (Connection conn = DriverManager.getConnection(URL)) {
            System.out.println("--- Criar tabela ---");
            criarTabela(conn);

            System.out.println("\\n--- Inserir dados ---");
            inserir(conn, "Ana Lima",    "ana@email.com",   9.0);
            inserir(conn, "Bruno Melo",  "bruno@email.com", 7.5);
            inserir(conn, "Carla Nunes", "carla@email.com", 8.0);
            inserir(conn, "Diego Faria", "diego@email.com", 6.5);
            System.out.println("✓ 4 registros inseridos");

            System.out.println("\\n--- Consultar (ordenado por nota) ---");
            listar(conn).forEach(System.out::println);

            System.out.println("\\n--- Estatísticas ---");
            estatisticas(conn);

            System.out.println("\\n--- Atualizar nota ---");
            try (PreparedStatement ps = conn.prepareStatement(
                    "UPDATE alunos SET nota = ? WHERE nome = ?")) {
                ps.setDouble(1, 8.5);
                ps.setString(2, "Bruno Melo");
                int rows = ps.executeUpdate();
                System.out.println("✓ " + rows + " registro(s) atualizado(s)");
            }

            System.out.println("\\n--- Após atualização ---");
            listar(conn).forEach(System.out::println);

        } catch (SQLException e) {
            System.err.println("Erro JDBC: " + e.getMessage());
            System.err.println("Certifique-se de que o sqlite-jdbc JAR está no classpath.");
            System.exit(1);
        }

        System.out.println("\\n✓ JDBC + SQLite testado com sucesso!");
    }
}
""",
                "README.md": """# Teste Java - JDBC + SQLite


**Objetivo:** Validar acesso a banco de dados com JDBC e SQLite

## Dependência: sqlite-jdbc
```bash
wget https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.45.1.0/sqlite-jdbc-3.45.1.0.jar
```

## Compilação e Execução
```bash
javac -cp sqlite-jdbc-*.jar JdbcSqlite.java
java  -cp .:sqlite-jdbc-*.jar JdbcSqlite
```

## Conceitos testados
- JDBC API (Connection, Statement, PreparedStatement, ResultSet)
- SQLite embarcado
- CRUD: INSERT, SELECT, UPDATE
- Consultas com ORDER BY e agregações (COUNT, AVG, MAX, MIN)
- `try-with-resources`

## Validação
- [ ] sqlite-jdbc.jar no classpath
- [ ] Banco criado automaticamente
- [ ] Inserção e consulta funcionando
- [ ] Atualização refletida corretamente
"""
            }
        },
        "01_basico": {
            "descricao": "Teste básico de Java e JDK",
            "files": {
                "Main.java": """/**
 * Teste básico Java

 * Valida: JDK, compilação, execução, classes
 */

public class Main {
    
    public static void main(String[] args) {
        System.out.println("=== Teste Java Básico ===");
        System.out.println();
        // Informações do ambiente
        System.out.println("Informações do Sistema:");
        System.out.println("Java Version: " + System.getProperty("java.version"));
        System.out.println("Java Vendor: " + System.getProperty("java.vendor"));
        System.out.println("OS: " + System.getProperty("os.name"));
        
        System.out.println("\\n--- Testes Básicos ---");
        
        // Teste de operações
        int a = 10, b = 5;
        System.out.println("Soma: " + a + " + " + b + " = " + (a + b));
        System.out.println("Multiplicação: " + a + " × " + b + " = " + (a * b));
        
        // Teste de String
        String mensagem = "Java funcionando!";
        System.out.println("\\nMensagem: " + mensagem);
        System.out.println("Tamanho: " + mensagem.length() + " caracteres");
        
        // Teste de array
        int[] numeros = {1, 2, 3, 4, 5};
        int soma = 0;
        for (int num : numeros) {
            soma += num;
        }
        System.out.println("\\nSoma do array: " + soma);
        
        System.out.println("\\n✓ Status: Ambiente Java configurado com sucesso!");
    }
}
""",
                "README.md": """# Teste Java Básico


**Objetivo:** Validar instalação JDK

## Compilação e Execução
```bash
javac Main.java
java Main
```

## Validação
- [ ] JDK instalado (verificar com `java -version`)
- [ ] Compilação sem erros
- [ ] Execução bem-sucedida
- [ ] Todas as saídas corretas

## Requisitos
- JDK 8 ou superior
"""
            }
        },
        "02_orientacao_objetos": {
            "descricao": "Teste de OO, encapsulamento e métodos",
            "files": {
                "Pessoa.java": """/**
 * Classe Pessoa - Demonstração de OO em Java

 * Testa: encapsulamento, construtores, métodos
 */

public class Pessoa {
    // Atributos privados (encapsulamento)
    private String nome;
    private int idade;
    private String email;
    
    // Construtor padrão
    public Pessoa() {
        this("Sem nome", 0, "sem@email.com");
    }
    
    // Construtor com parâmetros
    public Pessoa(String nome, int idade, String email) {
        this.nome = nome;
        this.idade = idade;
        this.email = email;
    }
    
    // Getters e Setters
    public String getNome() { return nome; }
    public void setNome(String nome) { this.nome = nome; }
    
    public int getIdade() { return idade; }
    public void setIdade(int idade) { 
        if (idade >= 0) this.idade = idade; 
    }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    // Métodos
    public void mostrar() {
        System.out.println("┌─────────────────────────────┐");
        System.out.println("│  Dados da Pessoa            │");
        System.out.println("├─────────────────────────────┤");
        System.out.printf("│  Nome:  %-20s│%n", nome);
        System.out.printf("│  Idade: %-20d│%n", idade);
        System.out.printf("│  Email: %-20s│%n", email);
        System.out.println("└─────────────────────────────┘");
    }
    
    public boolean isMaiorIdade() {
        return idade >= 18;
    }
    
    @Override
    public String toString() {
        return String.format("Pessoa[nome=%s, idade=%d, email=%s]", 
                           nome, idade, email);
    }
    
    // Método main para teste
    public static void main(String[] args) {
        System.out.println("=== Teste Java OO ===");
        System.out.println();
        // Teste 1: Construtor com parâmetros
        Pessoa p1 = new Pessoa("Rafael Silva", 35, "rafael@email.com");
        p1.mostrar();
        
        System.out.println("Maior de idade? " + 
                         (p1.isMaiorIdade() ? "Sim" : "Não"));
        
        System.out.println("\\n--- Teste 2 ---");
        
        // Teste 2: Construtor padrão e setters
        Pessoa p2 = new Pessoa();
        p2.setNome("Ana Santos");
        p2.setIdade(22);
        p2.setEmail("ana@email.com");
        p2.mostrar();
        
        System.out.println("\\n--- Teste toString() ---");
        System.out.println(p1.toString());
        System.out.println(p2.toString());
        
        System.out.println("\\n✓ Testes de OO concluídos com sucesso!");
    }
}
""",
                "README.md": """# Teste Java - Orientação a Objetos


**Objetivo:** Validar conceitos de OO em Java

## Compilação e Execução
```bash
javac Pessoa.java
java Pessoa
```

## Conceitos testados
- Encapsulamento (atributos privados)
- Construtores (padrão e parametrizado)
- Getters e Setters
- Métodos de instância
- Override de toString()
- Formatação de saída

## Validação
- [ ] Compilação sem warnings
- [ ] Objetos criados corretamente
- [ ] Métodos funcionando
- [ ] Encapsulamento respeitado
"""
            }
        }
    },
    
    "JavaScript": {
        "02_express_api": {
            "descricao": "API REST com Express.js, roteamento e middleware",
            "files": {
                "app.js": """/**
 * API REST com Express.js

 * Valida: Express, roteamento, middleware, JSON API
 */

const express = require('express');
const app = express();
const PORTA = 3001;

// ── Middleware ──────────────────────────────────────────────────
app.use(express.json());
app.use((req, res, next) => {
    const ts = new Date().toISOString();
    console.log(`[${ts}] ${req.method} ${req.path}`);
    next();
});

// ── Banco em memória ────────────────────────────────────────────
let alunos = [
    { id: 1, nome: 'Ana Lima',    email: 'ana@email.com',   nota: 9.0 },
    { id: 2, nome: 'Bruno Melo',  email: 'bruno@email.com', nota: 7.5 },
    { id: 3, nome: 'Carla Nunes', email: 'carla@email.com', nota: 8.0 },
];
let proximoId = 4;

// ── Rotas ───────────────────────────────────────────────────────
app.get('/', (req, res) => {
    res.json({
        mensagem: 'Express.js funcionando!',
        professor: 'Davi',
        endpoints: ['GET /alunos', 'GET /alunos/:id', 'POST /alunos',
                    'PUT /alunos/:id', 'DELETE /alunos/:id', 'GET /estatisticas'],
    });
});

// Listar todos (com filtro opcional ?nota_min=X)
app.get('/alunos', (req, res) => {
    const notaMin = parseFloat(req.query.nota_min);
    const resultado = isNaN(notaMin)
        ? alunos
        : alunos.filter(a => a.nota >= notaMin);
    res.json(resultado);
});

// Buscar por ID
app.get('/alunos/:id', (req, res) => {
    const aluno = alunos.find(a => a.id === parseInt(req.params.id));
    if (!aluno) return res.status(404).json({ erro: 'Aluno não encontrado' });
    res.json(aluno);
});

// Criar aluno
app.post('/alunos', (req, res) => {
    const { nome, email, nota } = req.body;
    if (!nome || !email || nota === undefined)
        return res.status(400).json({ erro: 'Campos obrigatórios: nome, email, nota' });
    if (nota < 0 || nota > 10)
        return res.status(400).json({ erro: 'Nota deve estar entre 0 e 10' });

    const novo = { id: proximoId++, nome, email, nota };
    alunos.push(novo);
    res.status(201).json(novo);
});

// Atualizar aluno
app.put('/alunos/:id', (req, res) => {
    const idx = alunos.findIndex(a => a.id === parseInt(req.params.id));
    if (idx === -1) return res.status(404).json({ erro: 'Aluno não encontrado' });
    alunos[idx] = { ...alunos[idx], ...req.body };
    res.json(alunos[idx]);
});

// Remover aluno
app.delete('/alunos/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const antes = alunos.length;
    alunos = alunos.filter(a => a.id !== id);
    if (alunos.length === antes) return res.status(404).json({ erro: 'Aluno não encontrado' });
    res.json({ mensagem: `Aluno ${id} removido` });
});

// Estatísticas
app.get('/estatisticas', (req, res) => {
    if (!alunos.length) return res.json({ total: 0 });
    const notas = alunos.map(a => a.nota);
    res.json({
        total:   alunos.length,
        media:   +(notas.reduce((s, n) => s + n, 0) / notas.length).toFixed(2),
        max:     Math.max(...notas),
        min:     Math.min(...notas),
        aprovados: alunos.filter(a => a.nota >= 7.0).length,
    });
});

// ── Iniciar servidor ────────────────────────────────────────────
app.listen(PORTA, () => {
    console.log('=== Teste Express.js ===');
    console.log(`Servidor: http://localhost:${PORTA}`);
    console.log('Pressione Ctrl+C para encerrar');
});
""",
                "package.json": """{
  "name": "teste-express-api",
  "version": "1.0.0",
  "description": "API REST com Express.js - Prof. Davi",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev":   "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "keywords": ["express", "rest", "api"],
  "author": "Prof. Davi",
  "license": "MIT"
}
""",
                "README.md": """# Teste JavaScript - Express.js REST API


**Objetivo:** Validar Express.js com CRUD completo e middlewares

## Instalação
```bash
npm install
```

## Execução
```bash
npm start
# ou
node app.js
```

## Endpoints
| Método | Rota | Descrição |
|--------|------|-----------|
| GET | / | Informações da API |
| GET | /alunos | Listar alunos |
| GET | /alunos/:id | Obter aluno |
| POST | /alunos | Criar aluno |
| PUT | /alunos/:id | Atualizar aluno |
| DELETE | /alunos/:id | Remover aluno |
| GET | /estatisticas | Estatísticas |

## Teste rápido via curl
```bash
curl http://localhost:3001/alunos
curl -X POST http://localhost:3001/alunos \\
  -H "Content-Type: application/json" \\
  -d '{"nome":"João","email":"joao@email.com","nota":8.0}'
```

## Validação
- [ ] npm install sem erros
- [ ] Servidor inicia corretamente
- [ ] GET/POST/PUT/DELETE funcionando
- [ ] Validação de campos ativa
"""
            }
        },
        "03_typescript_basico": {
            "descricao": "Tipagem estática, interfaces, generics e decorators em TypeScript",
            "files": {
                "index.ts": """/**
 * Teste TypeScript - Tipos, Interfaces e Generics

 * Valida: TypeScript, ts-node, sistema de tipos, generics
 */

// ── Tipos e Interfaces ──────────────────────────────────────────
interface Pessoa {
    readonly id: number;
    nome:  string;
    email: string;
}

interface Aluno extends Pessoa {
    matricula: string;
    notas:     number[];
}

// ── Função genérica ─────────────────────────────────────────────
function calcularMedia<T extends { notas: number[] }>(item: T): number {
    if (item.notas.length === 0) return 0;
    return item.notas.reduce((s, n) => s + n, 0) / item.notas.length;
}

// ── Classe tipada ───────────────────────────────────────────────
class Turma {
    private alunos: Aluno[] = [];

    adicionar(aluno: Aluno): void {
        this.alunos.push(aluno);
    }

    listar(): void {
        this.alunos.forEach(a => {
            const media = calcularMedia(a);
            const status = media >= 7.0 ? '✓ Aprovado' : '✗ Reprovado';
            console.log(`  ${a.nome.padEnd(18)} média: ${media.toFixed(2)}  ${status}`);
        });
    }

    estatisticas(): { total: number; media: number; aprovados: number } {
        const medias = this.alunos.map(calcularMedia);
        const aprovados = medias.filter(m => m >= 7.0).length;
        const media = medias.reduce((s, m) => s + m, 0) / (medias.length || 1);
        return { total: this.alunos.length, media, aprovados };
    }

    melhores(n: number): Aluno[] {
        return [...this.alunos]
            .sort((a, b) => calcularMedia(b) - calcularMedia(a))
            .slice(0, n);
    }
}

// ── Type aliases e Union types ──────────────────────────────────
type Resultado = 'aprovado' | 'reprovado' | 'recuperação';

function avaliar(nota: number): Resultado {
    if (nota >= 7.0) return 'aprovado';
    if (nota >= 5.0) return 'recuperação';
    return 'reprovado';
}

// ── Programa principal ──────────────────────────────────────────
console.log('=== Teste TypeScript ===');
console.log('');
const turma = new Turma();
turma.adicionar({ id: 1, nome: 'Ana Lima',    email: 'ana@email.com',   matricula: '2024001', notas: [8.0, 9.5, 7.5] });
turma.adicionar({ id: 2, nome: 'Bruno Melo',  email: 'bruno@email.com', matricula: '2024002', notas: [6.0, 5.5, 7.0] });
turma.adicionar({ id: 3, nome: 'Carla Nunes', email: 'carla@email.com', matricula: '2024003', notas: [9.0, 9.5, 8.5] });
turma.adicionar({ id: 4, nome: 'Diego Faria', email: 'diego@email.com', matricula: '2024004', notas: [4.0, 5.0, 6.0] });

console.log('--- Alunos e Médias ---');
turma.listar();

const stats = turma.estatisticas();
console.log(`\\n--- Estatísticas ---`);
console.log(`Total:      ${stats.total}`);
console.log(`Média geral: ${stats.media.toFixed(2)}`);
console.log(`Aprovados:  ${stats.aprovados}`);

console.log(`\\n--- Top 2 Alunos ---`);
turma.melhores(2).forEach((a, i) =>
    console.log(`  ${i + 1}. ${a.nome} (${calcularMedia(a).toFixed(2)})`)
);

console.log(`\\n--- Union Type (Resultado) ---`);
[9.0, 6.0, 4.0].forEach(n =>
    console.log(`  Nota ${n} → ${avaliar(n)}`)
);

console.log('\\n✓ TypeScript validado com sucesso!');
""",
                "tsconfig.json": """{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "outDir": "./dist",
    "rootDir": "./",
    "skipLibCheck": true
  },
  "include": ["*.ts"],
  "exclude": ["node_modules", "dist"]
}
""",
                "package.json": """{
  "name": "teste-typescript",
  "version": "1.0.0",
  "description": "Teste TypeScript - Prof. Davi",
  "scripts": {
    "start":   "ts-node index.ts",
    "build":   "tsc",
    "run-js":  "node dist/index.js"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "ts-node":    "^10.9.0",
    "@types/node": "^20.0.0"
  },
  "author": "Prof. Davi",
  "license": "MIT"
}
""",
                "README.md": """# Teste JavaScript - TypeScript Básico


**Objetivo:** Validar TypeScript com tipos estáticos, interfaces e generics

## Instalação
```bash
npm install
```

## Execução (com ts-node)
```bash
npm start
# ou
npx ts-node index.ts
```

## Compilar e executar JS
```bash
npm run build
npm run run-js
```

## Conceitos testados
- `interface` e herança de interfaces
- Classes com modificadores (`private`, `readonly`)
- Funções genéricas `<T extends ...>`
- Union types e type aliases
- Métodos tipados e retorno explícito

## Validação
- [ ] typescript e ts-node instalados
- [ ] Compilação sem erros de tipo
- [ ] Saída correta com tipagem verificada
"""
            }
        },
        "01_node_servidor_http": {
            "descricao": "Servidor HTTP básico com Node.js",
            "files": {
                "index.js": """/**
 * Servidor HTTP básico em Node.js

 * Valida: Node.js, módulos nativos, servidor web
 */

const http = require('http');
const url = require('url');

const PORTA = 3000;
const HOSTNAME = 'localhost';

// Contador de requisições
let contadorRequisicoes = 0;

const servidor = http.createServer((req, res) => {
    contadorRequisicoes++;
    
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    
    console.log(`[${new Date().toISOString()}] ${req.method} ${pathname}`);
    
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.statusCode = 200;
    
    if (pathname === '/') {
        res.end(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>Teste Node.js - Prof. Davi</title>
                <style>
                    body { font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px; }
                    .box { background: #f0f0f0; padding: 20px; border-radius: 8px; margin: 20px 0; }
                    .success { color: #28a745; }
                    h1 { color: #333; }
                </style>
            </head>
            <body>
                <h1>🚀 Teste Node.js</h1>
                
                <div class="box">
                    <h2 class="success">✓ Servidor Node.js funcionando!</h2>
                    <p><strong>Requisições atendidas:</strong> ${contadorRequisicoes}</p>
                    <p><strong>Porta:</strong> ${PORTA}</p>
                    <p><strong>Hora do servidor:</strong> ${new Date().toLocaleString('pt-BR')}</p>
                </div>
                <div class="box">
                    <h3>Endpoints disponíveis:</h3>
                    <ul>
                        <li><a href="/">/</a> - Página inicial</li>
                        <li><a href="/api">/api</a> - Resposta JSON</li>
                        <li><a href="/status">/status</a> - Status do servidor</li>
                    </ul>
                </div>
            </body>
            </html>
        `);
    } else if (pathname === '/api') {
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({
            status: 'success',
            mensagem: 'API funcionando',
            timestamp: Date.now(),
            requisicoes: contadorRequisicoes
        }, null, 2));
    } else if (pathname === '/status') {
        res.end(`
            <!DOCTYPE html>
            <html>
            <head><title>Status</title></head>
            <body>
                <h1>Status do Servidor</h1>
                <ul>
                    <li>Status: ✓ Online</li>
                    <li>Uptime: ${process.uptime().toFixed(2)}s</li>
                    <li>Memória: ${(process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2)} MB</li>
                    <li>Node.js: ${process.version}</li>
                </ul>
            </body>
            </html>
        `);
    } else {
        res.statusCode = 404;
        res.end('<h1>404 - Página não encontrada</h1>');
    }
});

servidor.listen(PORTA, HOSTNAME, () => {
    console.log('=== Teste Node.js ===');
    console.log(`Servidor rodando em http://${HOSTNAME}:${PORTA}/`);
    console.log('Pressione Ctrl+C para encerrar');
});

// Tratamento de encerramento gracioso
process.on('SIGINT', () => {
    console.log('\\n\\nEncerrando servidor...');
    servidor.close(() => {
        console.log('Servidor encerrado com sucesso!');
        process.exit(0);
    });
});
""",
                "package.json": """{
  "name": "teste-node-servidor-http",
  "version": "1.0.0",
  "description": "Teste de servidor HTTP em Node.js - Prof. Davi",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "keywords": ["teste", "node", "http", "servidor"],
  "author": "Prof. Davi",
  "license": "MIT"
}
""",
                "README.md": """# Teste Node.js - Servidor HTTP


**Objetivo:** Validar ambiente Node.js

## Execução
```bash
npm start
# ou
node index.js
```

## Teste
Abra no navegador: `http://localhost:3000`

## Endpoints
- `/` - Página inicial com informações
- `/api` - Resposta JSON
- `/status` - Status do servidor

## Validação
- [ ] Node.js instalado
- [ ] Servidor inicia sem erros
- [ ] Páginas carregam corretamente
- [ ] JSON retornado corretamente
"""
            }
        }
    },
    
    "CSharp": {
        "01_console_basico": {
            "descricao": "Aplicação console básica para validar .NET SDK",
            "files": {
                "Program.cs": """using System;

namespace TesteCSharp
{
    /// <summary>
    /// Programa de teste básico em C#
    /// Valida: .NET SDK, compilação, execução
    /// </summary>
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== Teste C# - Console Básico ===");
            Console.WriteLine($"Versão .NET: {Environment.Version}");
            Console.WriteLine($"Sistema Operacional: {Environment.OSVersion}");
            Console.WriteLine();
            
            // Teste de tipos e operações
            int a = 10, b = 5;
            Console.WriteLine($"Soma: {a} + {b} = {a + b}");
            Console.WriteLine($"Multiplicação: {a} × {b} = {a * b}");
            
            // Teste de string
            string mensagem = "C# funcionando!";
            Console.WriteLine($"\\nMensagem: {mensagem}");
            Console.WriteLine($"Tamanho: {mensagem.Length} caracteres");
            Console.WriteLine($"Maiúsculas: {mensagem.ToUpper()}");
            
            // Teste de array e LINQ
            int[] numeros = { 1, 2, 3, 4, 5 };
            int soma = numeros.Sum();
            double media = numeros.Average();
            
            Console.WriteLine($"\\nArray: [{string.Join(", ", numeros)}]");
            Console.WriteLine($"Soma: {soma}");
            Console.WriteLine($"Média: {media:F2}");
            
            Console.WriteLine("\\n✓ Status: Ambiente C# configurado com sucesso!");
        }
    }
}
""",
                "TesteCSharp.csproj": """<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>TesteCSharp</RootNamespace>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

</Project>
""",
                "README.md": """# Teste C# - Console Básico


**Objetivo:** Validar instalação .NET SDK

## Instalação do .NET SDK

### Ubuntu/Debian
```bash
wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y dotnet-sdk-8.0
```

### Verificar instalação
```bash
dotnet --version
# Deve mostrar 8.0.x
```

## Compilação e Execução
```bash
# Restaurar dependências e compilar
dotnet build

# Executar
dotnet run

# Ou compilar e executar em um comando
dotnet run
```

## Publicar aplicação
```bash
dotnet publish -c Release -o ./publish
./publish/TesteCSharp
```

## Validação
- [ ] .NET SDK 8.0+ instalado
- [ ] Compilação sem erros
- [ ] Execução bem-sucedida
- [ ] LINQ funcionando
- [ ] Todas as saídas corretas
"""
            }
        },
        "02_orientacao_objetos": {
            "descricao": "Classes, propriedades, herança e polimorfismo",
            "files": {
                "Program.cs": """using System;
using System.Collections.Generic;
using System.Linq;

namespace TesteOO
{
    /// <summary>
    /// Classe base Pessoa com encapsulamento
    /// </summary>
    public class Pessoa
    {
        // Propriedades auto-implementadas
        public string Nome { get; set; }
        public int Idade { get; set; }
        public string Email { get; set; }
        
        // Construtor
        public Pessoa(string nome, int idade, string email)
        {
            Nome = nome;
            Idade = idade;
            Email = email;
        }
        
        // Método virtual para polimorfismo
        public virtual void Apresentar()
        {
            Console.WriteLine($"Nome: {Nome}");
            Console.WriteLine($"Idade: {Idade} anos");
            Console.WriteLine($"Email: {Email}");
        }
        
        public bool EhMaiorIdade() => Idade >= 18;
    }
    
    /// <summary>
    /// Classe derivada Aluno com propriedades específicas
    /// </summary>
    public class Aluno : Pessoa
    {
        public string Matricula { get; set; }
        public List<double> Notas { get; set; }
        
        public Aluno(string nome, int idade, string email, string matricula) 
            : base(nome, idade, email)
        {
            Matricula = matricula;
            Notas = new List<double>();
        }
        
        public void AdicionarNota(double nota)
        {
            if (nota >= 0 && nota <= 10)
                Notas.Add(nota);
        }
        
        public double CalcularMedia()
        {
            return Notas.Any() ? Notas.Average() : 0;
        }
        
        public override void Apresentar()
        {
            Console.WriteLine("┌─────────────────────────────────────┐");
            Console.WriteLine("│       DADOS DO ALUNO                │");
            Console.WriteLine("├─────────────────────────────────────┤");
            Console.WriteLine($"│  Nome:      {Nome,-25}│");
            Console.WriteLine($"│  Matrícula: {Matricula,-25}│");
            Console.WriteLine($"│  Idade:     {Idade,-25}│");
            Console.WriteLine($"│  Email:     {Email,-25}│");
            Console.WriteLine($"│  Média:     {CalcularMedia(),-25:F2}│");
            Console.WriteLine("└─────────────────────────────────────┘");
        }
    }
    
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== Teste C# - Orientação a Objetos ===\\n");
            
            // Teste 1: Classe base Pessoa
            Console.WriteLine("--- Teste 1: Classe Pessoa ---");
            var pessoa = new Pessoa("Maria Silva", 25, "maria@email.com");
            pessoa.Apresentar();
            Console.WriteLine($"Maior de idade? {(pessoa.EhMaiorIdade() ? "Sim" : "Não")}");
            
            Console.WriteLine("\\n--- Teste 2: Classe Aluno (Herança) ---");
            var aluno = new Aluno("João Santos", 20, "joao@email.com", "2024001");
            aluno.AdicionarNota(8.5);
            aluno.AdicionarNota(7.0);
            aluno.AdicionarNota(9.0);
            aluno.AdicionarNota(8.0);
            aluno.Apresentar();
            
            Console.WriteLine("\\n--- Teste 3: Coleção de Objetos ---");
            var alunos = new List<Aluno>
            {
                new Aluno("Ana Costa", 19, "ana@email.com", "2024002"),
                new Aluno("Pedro Lima", 21, "pedro@email.com", "2024003")
            };
            
            alunos[0].AdicionarNota(9.5);
            alunos[0].AdicionarNota(8.5);
            alunos[1].AdicionarNota(7.0);
            alunos[1].AdicionarNota(7.5);
            
            Console.WriteLine($"Total de alunos: {alunos.Count}");
            Console.WriteLine($"Média geral: {alunos.Average(a => a.CalcularMedia()):F2}");
            
            Console.WriteLine("\\n--- Teste 4: Polimorfismo ---");
            List<Pessoa> pessoas = new List<Pessoa>
            {
                pessoa,
                aluno
            };
            
            foreach (var p in pessoas)
            {
                Console.WriteLine($"\\nTipo: {p.GetType().Name}");
                p.Apresentar();
            }
            
            Console.WriteLine("\\n✓ Testes de OO concluídos com sucesso!");
        }
    }
}
""",
                "TesteOO.csproj": """<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>TesteOO</RootNamespace>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

</Project>
""",
                "README.md": """# Teste C# - Orientação a Objetos


**Objetivo:** Validar conceitos de OO em C#

## Compilação e Execução
```bash
dotnet build
dotnet run
```

## Conceitos testados
- Encapsulamento (propriedades)
- Construtores
- Herança (Pessoa → Aluno)
- Polimorfismo (override de métodos)
- Coleções genéricas (List<T>)
- LINQ (Average, Any)
- Expressões lambda
- Properties auto-implementadas

## Validação
- [ ] Compilação sem warnings
- [ ] Classes criadas corretamente
- [ ] Herança funcionando
- [ ] Polimorfismo executando
- [ ] LINQ processando coleções
"""
            }
        },
        "03_aspnet_webapi": {
            "descricao": "API REST básica com ASP.NET Core",
            "files": {
                "Program.cs": """using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = WebApplication.CreateBuilder(args);

// Adicionar serviços
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configurar pipeline HTTP
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Dados de exemplo (em memória)
var alunos = new List<Aluno>
{
    new Aluno(1, "João Silva", "joao@email.com", 8.5),
    new Aluno(2, "Maria Santos", "maria@email.com", 9.0),
    new Aluno(3, "Pedro Costa", "pedro@email.com", 7.5)
};

// Endpoints da API
app.MapGet("/", () => new
{
    mensagem = "API C# funcionando!",
    versao = "1.0",
    endpoints = new[]
    {
        "GET /",
        "GET /api/alunos",
        "GET /api/alunos/{id}",
        "POST /api/alunos",
        "GET /api/status"
    }
})
.WithName("Root")
.WithTags("Info");

app.MapGet("/api/alunos", () => Results.Ok(alunos))
    .WithName("GetAlunos")
    .WithTags("Alunos");

app.MapGet("/api/alunos/{id}", (int id) =>
{
    var aluno = alunos.FirstOrDefault(a => a.Id == id);
    return aluno is not null ? Results.Ok(aluno) : Results.NotFound();
})
.WithName("GetAluno")
.WithTags("Alunos");

app.MapPost("/api/alunos", (AlunoInput novoAluno) =>
{
    var aluno = new Aluno(
        alunos.Max(a => a.Id) + 1,
        novoAluno.Nome,
        novoAluno.Email,
        novoAluno.Nota
    );
    alunos.Add(aluno);
    return Results.Created($"/api/alunos/{aluno.Id}", aluno);
})
.WithName("CreateAluno")
.WithTags("Alunos");

app.MapGet("/api/status", () => new
{
    status = "online",
    totalAlunos = alunos.Count,
    mediaGeral = alunos.Average(a => a.Nota),
    timestamp = DateTime.Now
})
.WithName("GetStatus")
.WithTags("Info");

Console.WriteLine("=== API C# - ASP.NET Core ===");
Console.WriteLine($"Ambiente: {app.Environment.EnvironmentName}");
Console.WriteLine("Servidor iniciado!");
Console.WriteLine("Acesse: http://localhost:5000");
Console.WriteLine("Swagger UI: http://localhost:5000/swagger");
Console.WriteLine("Pressione Ctrl+C para encerrar");

app.Run();

// Modelos
record Aluno(int Id, string Nome, string Email, double Nota);
record AlunoInput(string Nome, string Email, double Nota);
""",
                "TesteWebAPI.csproj": """<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
  </ItemGroup>

</Project>
""",
                "appsettings.json": """{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "Urls": "http://localhost:5000"
}
""",
                "README.md": """# Teste C# - ASP.NET Core Web API


**Objetivo:** Validar ASP.NET Core e criação de APIs REST

## Compilação e Execução
```bash
dotnet restore
dotnet build
dotnet run
```

## Teste da API

### Via navegador
- Página inicial: `http://localhost:5000`
- Swagger UI: `http://localhost:5000/swagger`

### Via curl
```bash
# Listar todos os alunos
curl http://localhost:5000/api/alunos

# Obter aluno específico
curl http://localhost:5000/api/alunos/1

# Criar novo aluno (sem passar Id)
curl -X POST http://localhost:5000/api/alunos \\
  -H "Content-Type: application/json" \\
  -d '{"nome":"Ana Lima","email":"ana@email.com","nota":8.8}'

# Status da API
curl http://localhost:5000/api/status
```

## Recursos testados
- ASP.NET Core Minimal APIs
- Swagger/OpenAPI
- HTTP GET/POST endpoints
- Roteamento
- Serialização JSON
- Records (C# 9+)
- LINQ com coleções
- Separação de DTOs (AlunoInput vs Aluno)

## Validação
- [ ] API inicia sem erros
- [ ] Swagger UI acessível
- [ ] Endpoints GET funcionando
- [ ] Endpoint POST criando recursos
- [ ] JSON sendo serializado corretamente
"""
            }
        },
        "04_entity_framework": {
            "descricao": "Acesso a dados com Entity Framework Core e SQLite",
            "files": {
                "Program.cs": """using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;

namespace TesteEF
{
    // Modelo de dados
    public class Aluno
    {
        public int Id { get; set; }
        public string Nome { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public double Nota { get; set; }
        public DateTime DataCadastro { get; set; }
    }
    
    // Contexto do banco de dados
    public class AppDbContext : DbContext
    {
        public DbSet<Aluno> Alunos { get; set; }
        
        protected override void OnConfiguring(DbContextOptionsBuilder options)
        {
            options.UseSqlite("Data Source=teste.db");
        }
    }
    
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("=== Teste C# - Entity Framework Core ===\\n");
            
            using (var db = new AppDbContext())
            {
                // Criar banco de dados
                Console.WriteLine("--- Criando banco de dados ---");
                db.Database.EnsureDeleted();
                db.Database.EnsureCreated();
                Console.WriteLine("✓ Banco criado: teste.db\\n");
                
                // Inserir dados
                Console.WriteLine("--- Inserindo dados ---");
                var alunos = new[]
                {
                    new Aluno { Nome = "João Silva", Email = "joao@email.com", Nota = 8.5, DataCadastro = DateTime.Now },
                    new Aluno { Nome = "Maria Santos", Email = "maria@email.com", Nota = 9.0, DataCadastro = DateTime.Now },
                    new Aluno { Nome = "Pedro Costa", Email = "pedro@email.com", Nota = 7.5, DataCadastro = DateTime.Now },
                    new Aluno { Nome = "Ana Lima", Email = "ana@email.com", Nota = 9.5, DataCadastro = DateTime.Now }
                };
                
                db.Alunos.AddRange(alunos);
                db.SaveChanges();
                Console.WriteLine($"✓ {alunos.Length} alunos inseridos\\n");
                
                // Consultar todos
                Console.WriteLine("--- Consultando todos os alunos ---");
                var todosAlunos = db.Alunos.ToList();
                foreach (var aluno in todosAlunos)
                {
                    Console.WriteLine($"ID: {aluno.Id} | {aluno.Nome} | Nota: {aluno.Nota:F2}");
                }
                Console.WriteLine();
                
                // Consultar com filtro (LINQ)
                Console.WriteLine("--- Alunos com nota >= 9.0 ---");
                var alunosDestaque = db.Alunos
                    .Where(a => a.Nota >= 9.0)
                    .OrderByDescending(a => a.Nota)
                    .ToList();
                
                foreach (var aluno in alunosDestaque)
                {
                    Console.WriteLine($"{aluno.Nome}: {aluno.Nota:F2}");
                }
                Console.WriteLine();
                
                // Estatísticas (agregação)
                Console.WriteLine("--- Estatísticas ---");
                var total = db.Alunos.Count();
                var media = db.Alunos.Average(a => a.Nota);
                var maiorNota = db.Alunos.Max(a => a.Nota);
                var menorNota = db.Alunos.Min(a => a.Nota);
                
                Console.WriteLine($"Total de alunos: {total}");
                Console.WriteLine($"Média geral: {media:F2}");
                Console.WriteLine($"Maior nota: {maiorNota:F2}");
                Console.WriteLine($"Menor nota: {menorNota:F2}");
                Console.WriteLine();
                
                // Atualizar registro
                Console.WriteLine("--- Atualizando registro ---");
                var alunoAtualizar = db.Alunos.First(a => a.Nome == "João Silva");
                Console.WriteLine($"Nota anterior de {alunoAtualizar.Nome}: {alunoAtualizar.Nota:F2}");
                alunoAtualizar.Nota = 9.2;
                db.SaveChanges();
                Console.WriteLine($"Nota atualizada: {alunoAtualizar.Nota:F2}\\n");
                
                // Deletar registro
                Console.WriteLine("--- Deletando registro ---");
                var alunoDeletar = db.Alunos.First(a => a.Nome == "Pedro Costa");
                Console.WriteLine($"Deletando: {alunoDeletar.Nome}");
                db.Alunos.Remove(alunoDeletar);
                db.SaveChanges();
                Console.WriteLine($"Total após deleção: {db.Alunos.Count()} alunos\\n");
                
                Console.WriteLine("✓ Testes Entity Framework concluídos com sucesso!");
            }
        }
    }
}
""",
                "TesteEF.csproj": """<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>TesteEF</RootNamespace>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.Sqlite" Version="8.0.0" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.0">
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
  </ItemGroup>

</Project>
""",
                "README.md": """# Teste C# - Entity Framework Core


**Objetivo:** Validar ORM Entity Framework Core com SQLite

## Compilação e Execução
```bash
dotnet restore
dotnet build
dotnet run
```

## O que é testado
1. **Criação de banco de dados** (SQLite)
2. **Operações CRUD**:
   - Create (Insert)
   - Read (Select)
   - Update
   - Delete
3. **LINQ to Entities**:
   - Where, OrderBy
   - Count, Average, Max, Min
4. **Code First**: Classes → Tabelas
5. **Migrations**: Schema automático

## Arquivos gerados
- `teste.db` - Banco de dados SQLite

## Conceitos testados
- DbContext
- DbSet<T>
- CRUD operations
- LINQ queries
- Agregações
- Relacionamento objeto-relacional

## Validação
- [ ] Banco de dados criado
- [ ] Dados inseridos
- [ ] Consultas LINQ funcionando
- [ ] Atualização executada
- [ ] Deleção executada
- [ ] Estatísticas corretas
"""
            }
        }
    },
    
    "Rust": {
        "01_hello_cargo": {
            "descricao": "Projeto Cargo básico: hello world, tipos e estruturas de controle",
            "files": {
                "src/main.rs": """//! Teste Rust básico com Cargo

//! Valida: compilador rustc, Cargo, tipos, ownership básico

fn saudar(nome: &str) -> String {
    format!("Olá, {}! Rust está funcionando.", nome)
}

fn calcular_fatorial(n: u64) -> u64 {
    match n {
        0 | 1 => 1,
        _ => n * calcular_fatorial(n - 1),
    }
}

fn estatisticas(nums: &[f64]) -> (f64, f64, f64) {
    let n = nums.len() as f64;
    let soma: f64 = nums.iter().sum();
    let media = soma / n;
    let min = nums.iter().cloned().fold(f64::INFINITY, f64::min);
    let max = nums.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    (media, min, max)
}

fn main() {
    println!("=== Teste Rust Básico ===");
    println!("");

    // Tipos básicos e string formatting
    let nome = "Rust";
    println!("{}", saudar(nome));

    // Versão do compilador (via env)
    println!("Rustc: {}", env!("CARGO_PKG_RUST_VERSION",
        "versão desconhecida (defina em Cargo.toml)"));

    // Estruturas de controle e match
    println!("\\n--- Fatorial (match recursivo) ---");
    for n in [0u64, 1, 5, 10] {
        println!("  {}! = {}", n, calcular_fatorial(n));
    }

    // Iteradores e closures
    println!("\\n--- Iteradores e Closures ---");
    let notas: Vec<f64> = vec![7.5, 8.0, 6.5, 9.0, 8.5];
    let aprovados: Vec<f64> = notas.iter().cloned().filter(|&n| n >= 7.0).collect();
    println!("  Notas: {:?}", notas);
    println!("  Aprovados (≥7.0): {:?}", aprovados);

    let (media, min, max) = estatisticas(&notas);
    println!("  Média: {:.2}  Min: {:.1}  Max: {:.1}", media, min, max);

    // Option e Result básico
    println!("\\n--- Option e Result ---");
    let valores = vec![10, 20, 30];
    match valores.get(1) {
        Some(v) => println!("  get(1) = {}", v),
        None    => println!("  Índice fora dos limites"),
    }

    let texto = "42";
    match texto.parse::<i32>() {
        Ok(n)  => println!("  parse('{}') = {}", texto, n),
        Err(e) => println!("  Erro: {}", e),
    }

    println!("\\n✓ Rust e Cargo funcionando corretamente!");
}
""",
                "Cargo.toml": """[package]
name    = "teste-rust-basico"
version = "0.1.0"
edition = "2021"
rust-version = "1.70"
authors = ["Prof. Vários"]
description = "Teste básico do ambiente Rust"

[dependencies]

[profile.release]
opt-level = 3
""",
                "README.md": """# Teste Rust - Hello Cargo


**Objetivo:** Validar compilador Rust, Cargo e construtos básicos da linguagem

## Pré-requisitos
```bash
# Instalar Rust via rustup (já feito pelo instalador de laboratório)
rustup --version
cargo --version
rustc --version
```

## Compilação e Execução
```bash
cargo run             # compilar e executar (modo debug)
cargo run --release   # modo otimizado
cargo build           # apenas compilar
cargo test            # rodar testes
cargo clippy          # linter
```

## Conceitos testados
- Funções com retorno de tipos primitivos e `String`
- `match` com padrões
- Vetores e iteradores com `filter`, `cloned`, `collect`
- Closures (`|n| n >= 7.0`)
- `Option<T>` e `Result<T, E>`
- Referências e empréstimo (`&[f64]`)

## Validação
- [ ] `cargo run` funciona
- [ ] Sem warnings de compilação
- [ ] Todos os valores impressos corretamente
"""
            }
        },
        "02_ownership_borrowing": {
            "descricao": "Ownership, borrowing, lifetimes e gestão de memória sem GC",
            "files": {
                "src/main.rs": """//! Teste Rust - Ownership, Borrowing e Lifetimes

//! Valida: sistema de ownership, referências, borrow checker

use std::collections::HashMap;

// ── Ownership: move semântico ─────────────────────────────────
fn consumir_string(s: String) -> usize {
    println!("  Consumindo: '{}' (len={})", s, s.len());
    s.len()
}

// ── Borrowing imutável ───────────────────────────────────────
fn comprimento(s: &str) -> usize {
    s.len()
}

// ── Borrowing mutável ────────────────────────────────────────
fn adicionar_sufixo(s: &mut String, sufixo: &str) {
    s.push_str(sufixo);
}

// ── Lifetimes explícitos ─────────────────────────────────────
fn maior_str<'a>(a: &'a str, b: &'a str) -> &'a str {
    if a.len() >= b.len() { a } else { b }
}

// ── Struct com referência + lifetime ────────────────────────
struct Trecho<'a> {
    parte: &'a str,
}

impl<'a> Trecho<'a> {
    fn nova(texto: &'a str, inicio: usize, fim: usize) -> Self {
        Trecho { parte: &texto[inicio..fim] }
    }
    fn exibir(&self) {
        println!("  Trecho: '{}'", self.parte);
    }
}

// ── Clone vs Move ────────────────────────────────────────────
#[derive(Debug, Clone)]
struct Aluno {
    nome: String,
    nota: f64,
}

fn main() {
    println!("=== Teste Rust - Ownership e Borrowing ===");
    println!("");

    // Move semântico
    println!("--- Move Semântico ---");
    let s1 = String::from("Laboratório de Rust");
    let len = consumir_string(s1);
    // s1 não está mais disponível aqui
    println!("  Comprimento retornado: {}\\n", len);

    // Borrow imutável (múltiplos leitores simultâneos)
    println!("--- Borrow Imutável ---");
    let texto = String::from("Programação em Rust");
    let len1 = comprimento(&texto);
    let len2 = comprimento(&texto);   // segunda referência OK
    println!("  '{}' tem {} / {} chars\\n", texto, len1, len2);

    // Borrow mutável (exclusivo)
    println!("--- Borrow Mutável ---");
    let mut mutable = String::from("Rust");
    adicionar_sufixo(&mut mutable, " é seguro!");
    println!("  Resultado: {}\\n", mutable);

    // Lifetimes
    println!("--- Lifetimes ---");
    let a = String::from("hello");
    let resultado;
    {
        let b = String::from("mundo ampliado");
        resultado = maior_str(&a, &b);
        println!("  Maior: '{}' (len={})", resultado, resultado.len());
    }

    // Slice com lifetime
    println!("\\n--- Struct com Lifetime ---");
    let frase = String::from("aprendendo Rust com segurança");
    let trecho = Trecho::nova(&frase, 11, 15);
    trecho.exibir();

    // Clone explícito
    println!("\\n--- Clone vs Move ---");
    let a1 = Aluno { nome: "Ana".to_string(), nota: 9.0 };
    let a2 = a1.clone();             // clone: a1 ainda existe
    println!("  Original: {:?}", a1);
    println!("  Clone:    {:?}", a2);

    // HashMap e ownership de chaves/valores
    println!("\\n--- HashMap e Ownership ---");
    let mut mapa: HashMap<String, f64> = HashMap::new();
    mapa.insert("Ana".to_string(), 9.0);
    mapa.insert("Bruno".to_string(), 7.5);
    for (nome, nota) in &mapa {
        println!("  {} → {:.1}", nome, nota);
    }

    println!("\\n✓ Ownership e Borrowing testados sem erros de memória!");
}
""",
                "Cargo.toml": """[package]
name    = "teste-rust-ownership"
version = "0.1.0"
edition = "2021"
authors = ["Prof. Vários"]
description = "Teste de Ownership e Borrowing em Rust"

[dependencies]
""",
                "README.md": """# Teste Rust - Ownership e Borrowing


**Objetivo:** Validar o sistema de ownership do Rust: memória segura sem GC

## Execução
```bash
cargo run
cargo clippy   # linter — deve passar sem warnings
```

## Conceitos testados
- **Move semântico**: variável invalidada após mover
- **Borrow imutável** (`&T`): múltiplos leitores simultâneos
- **Borrow mutável** (`&mut T`): acesso exclusivo
- **Lifetimes** (`'a`): garantia de validade de referências
- **Struct com lifetime** (`Trecho<'a>`)
- **Clone** explícito vs. move
- **HashMap** com ownership de chaves e valores

## Por que isso importa?
Rust garante ausência de:
- Use-after-free
- Double-free
- Data races em threads

...em **tempo de compilação**, sem garbage collector.

## Validação
- [ ] `cargo run` sem erros
- [ ] `cargo clippy` sem warnings
- [ ] Borrow checker validado (experimente remover .clone() e veja o erro)
"""
            }
        }
    },

    "HPC": {
        "03_hibrido_openmp_mpi": {
            "descricao": "Computação híbrida: MPI entre nós + OpenMP dentro de cada nó",
            "files": {
                "hibrido.c": """#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <mpi.h>

/**
 * Teste HPC Híbrido - MPI + OpenMP

 * Valida: programação híbrida, múltiplos níveis de paralelismo
 *
 * Compilação: mpicc -fopenmp -o hibrido hibrido.c
 * Execução:   OMP_NUM_THREADS=4 mpirun -np 2 ./hibrido
 */

#define N 16  /* elementos por processo MPI */

int main(int argc, char **argv) {
    int rank, size;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    /* --- Informações de ambiente --- */
    int max_threads = omp_get_max_threads();

    if (rank == 0) {
        printf("=== Teste HPC Híbrido MPI + OpenMP ===\\n");
        printf("Processos MPI: %d\\n", size);
        printf("Threads/processo (OpenMP): %d\\n\\n", max_threads);
    }
    MPI_Barrier(MPI_COMM_WORLD);

    /* --- Trabalho paralelo híbrido --- */
    double soma_local = 0.0;
    double tempo_inicio = MPI_Wtime();

    #pragma omp parallel for reduction(+:soma_local) schedule(dynamic)
    for (int i = 0; i < N; i++) {
        int idx_global = rank * N + i;
        soma_local += (double)idx_global;

        #pragma omp critical
        {
            /* Apenas p/ demonstração — não use critical em produção assim */
            if (rank == 0 && omp_get_thread_num() == 0 && i == 0) {
                printf("Rank %d usando %d threads OpenMP\\n",
                       rank, omp_get_num_threads());
            }
        }
    }

    double tempo_fim = MPI_Wtime();

    /* --- Redução global via MPI --- */
    double soma_global = 0.0;
    MPI_Reduce(&soma_local, &soma_global, 1, MPI_DOUBLE,
               MPI_SUM, 0, MPI_COMM_WORLD);

    if (rank == 0) {
        int total_elementos = N * size;
        double esperado = (double)(total_elementos - 1) * total_elementos / 2.0;

        printf("\\nResultados:\\n");
        printf("  Soma calculada:  %.0f\\n", soma_global);
        printf("  Soma esperada:   %.0f\\n", esperado);
        printf("  Correto:         %s\\n",
               (soma_global == esperado) ? "SIM ✓" : "NÃO ✗");
        printf("  Tempo (rank 0):  %.6f s\\n", tempo_fim - tempo_inicio);
        printf("  Eficiência: %d proc × %d threads = %d núcleos lógicos\\n",
               size, max_threads, size * max_threads);
        printf("\\n✓ Teste híbrido MPI + OpenMP concluído!\\n");
    }

    MPI_Finalize();
    return EXIT_SUCCESS;
}
""",
                "README.md": """# Teste HPC - Híbrido MPI + OpenMP


**Objetivo:** Validar programação paralela híbrida (distribuída + memória compartilhada)

## Compilação
```bash
mpicc -fopenmp -Wall -O2 -o hibrido hibrido.c
```

## Execução
```bash
# 2 processos MPI × 4 threads OpenMP = 8 núcleos lógicos
OMP_NUM_THREADS=4 mpirun -np 2 ./hibrido

# 4 processos MPI × 2 threads OpenMP = 8 núcleos lógicos
OMP_NUM_THREADS=2 mpirun -np 4 ./hibrido
```

## Conceitos testados
- Dois níveis de paralelismo: MPI (entre nós) + OpenMP (intra-nó)
- `#pragma omp parallel for reduction` dentro de processo MPI
- `MPI_Reduce` para agregação global
- `MPI_Wtime` para medição de tempo
- `MPI_Barrier` para sincronização

## Validação
- [ ] Compilação com `-fopenmp` e MPI
- [ ] Resultado matematicamente correto
- [ ] Múltiplas threads por processo confirmadas
- [ ] Sincronização entre processos funcionando
""",
                "Makefile": """MPICC  = mpicc
CFLAGS = -Wall -Wextra -fopenmp -O2
TARGET = hibrido

all: $(TARGET)

$(TARGET): hibrido.c
\t$(MPICC) $(CFLAGS) -o $(TARGET) hibrido.c

clean:
\trm -f $(TARGET)

run2x4: $(TARGET)
\tOMP_NUM_THREADS=4 mpirun -np 2 ./$(TARGET)

run4x2: $(TARGET)
\tOMP_NUM_THREADS=2 mpirun -np 4 ./$(TARGET)
"""
            }
        },
        "01_openmp": {
            "descricao": "Programação paralela com OpenMP",
            "files": {
                "omp_test.c": """#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

/**
 * Teste OpenMP - Programação Paralela

 * Valida: compilação com OpenMP, threads, paralelização
 */

#define N 1000000

void teste_basico() {
    printf("\\n--- Teste Básico de Threads ---\\n");
    
    #pragma omp parallel
    {
        int tid = omp_get_thread_num();
        int nthreads = omp_get_num_threads();
        
        #pragma omp critical
        {
            printf("Thread %d de %d: Olá!\\n", tid, nthreads);
        }
    }
}

void teste_reducao() {
    printf("\\n--- Teste de Redução Paralela ---\\n");
    
    long long soma = 0;
    double inicio, fim;
    
    // Versão serial
    inicio = omp_get_wtime();
    for (long long i = 0; i < N; i++) {
        soma += i;
    }
    fim = omp_get_wtime();
    printf("Serial - Soma: %lld, Tempo: %.4f s\\n", soma, fim - inicio);
    
    // Versão paralela
    soma = 0;
    inicio = omp_get_wtime();
    #pragma omp parallel for reduction(+:soma)
    for (long long i = 0; i < N; i++) {
        soma += i;
    }
    fim = omp_get_wtime();
    printf("Paralelo - Soma: %lld, Tempo: %.4f s\\n", soma, fim - inicio);
}

void teste_schedule() {
    printf("\\n--- Teste de Scheduling ---\\n");
    
    #pragma omp parallel for schedule(static, 2)
    for (int i = 0; i < 12; i++) {
        printf("Thread %d processa iteração %d\\n", 
               omp_get_thread_num(), i);
    }
}

int main(void) {
    printf("=== Teste OpenMP ===\\n");
    printf("Número máximo de threads: %d\\n", omp_get_max_threads());
    printf("Número de processadores: %d\\n", omp_get_num_procs());
    
    teste_basico();
    teste_reducao();
    teste_schedule();
    
    printf("\\n✓ Testes OpenMP concluídos!\\n");
    return EXIT_SUCCESS;
}
""",
                "README.md": """# Teste HPC - OpenMP


**Objetivo:** Validar programação paralela com OpenMP

## Compilação
```bash
gcc -fopenmp -o omp_test omp_test.c
./omp_test
```

## Controle de Threads
```bash
export OMP_NUM_THREADS=4
./omp_test
```

## Conceitos testados
- Regiões paralelas
- Identificação de threads
- Redução paralela
- Scheduling strategies
- Medição de tempo

## Validação
- [ ] OpenMP disponível no compilador
- [ ] Múltiplas threads executando
- [ ] Redução paralela correta
- [ ] Speedup observado
""",
                "Makefile": """CC = gcc
CFLAGS = -Wall -Wextra -fopenmp
TARGET = omp_test

all: $(TARGET)

$(TARGET): omp_test.c
\t$(CC) $(CFLAGS) -o $(TARGET) omp_test.c

clean:
\trm -f $(TARGET)

run: $(TARGET)
\t./$(TARGET)

run4: $(TARGET)
\tOMP_NUM_THREADS=4 ./$(TARGET)

run8: $(TARGET)
\tOMP_NUM_THREADS=8 ./$(TARGET)
"""
            }
        },
        "02_mpi": {
            "descricao": "Computação distribuída com MPI",
            "files": {
                "mpi_test.c": """#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>
#include <string.h>

/**
 * Teste MPI - Computação Distribuída

 * Valida: MPI instalado, comunicação entre processos
 */

#define MASTER 0

void teste_hello_world(int rank, int size) {
    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len;
    
    MPI_Get_processor_name(processor_name, &name_len);
    
    printf("Processo %d de %d em %s\\n", rank, size, processor_name);
    
    if (rank == MASTER) {
        printf("\\n=== Teste MPI ===\\n");
        printf("Total de processos: %d\\n", size);
    }
}

void teste_comunicacao(int rank, int size) {
    if (rank == MASTER) {
        printf("\\n--- Teste de Comunicação Point-to-Point ---\\n");
        
        // Master envia mensagens
        for (int dest = 1; dest < size; dest++) {
            int valor = dest * 100;
            MPI_Send(&valor, 1, MPI_INT, dest, 0, MPI_COMM_WORLD);
            printf("Master enviou %d para processo %d\\n", valor, dest);
        }
        
        // Master recebe respostas
        for (int source = 1; source < size; source++) {
            int resultado;
            MPI_Recv(&resultado, 1, MPI_INT, source, 1, MPI_COMM_WORLD, 
                    MPI_STATUS_IGNORE);
            printf("Master recebeu %d do processo %d\\n", resultado, source);
        }
    } else {
        // Workers recebem e processam
        int valor;
        MPI_Recv(&valor, 1, MPI_INT, MASTER, 0, MPI_COMM_WORLD, 
                MPI_STATUS_IGNORE);
        
        int resultado = valor * 2;  // Processamento simples
        
        MPI_Send(&resultado, 1, MPI_INT, MASTER, 1, MPI_COMM_WORLD);
    }
}

void teste_broadcast(int rank, int size) {
    int valor;
    
    if (rank == MASTER) {
        printf("\\n--- Teste de Broadcast ---\\n");
        valor = 42;
        printf("Master broadcasting valor %d\\n", valor);
    }
    
    MPI_Bcast(&valor, 1, MPI_INT, MASTER, MPI_COMM_WORLD);
    
    if (rank != MASTER) {
        printf("Processo %d recebeu broadcast: %d\\n", rank, valor);
    }
}

void teste_reduce(int rank, int size) {
    int local_valor = rank + 1;
    int soma_total;
    
    if (rank == MASTER) {
        printf("\\n--- Teste de Reduce (Soma) ---\\n");
    }
    
    MPI_Reduce(&local_valor, &soma_total, 1, MPI_INT, MPI_SUM, 
              MASTER, MPI_COMM_WORLD);
    
    if (rank == MASTER) {
        printf("Soma de todos os processos: %d\\n", soma_total);
        printf("(Esperado: %d)\\n", size * (size + 1) / 2);
    }
}

int main(int argc, char** argv) {
    int rank, size;
    
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    teste_hello_world(rank, size);
    MPI_Barrier(MPI_COMM_WORLD);
    
    if (size > 1) {
        teste_comunicacao(rank, size);
        MPI_Barrier(MPI_COMM_WORLD);
        
        teste_broadcast(rank, size);
        MPI_Barrier(MPI_COMM_WORLD);
        
        teste_reduce(rank, size);
    } else {
        if (rank == MASTER) {
            printf("\\n⚠ Execute com múltiplos processos para testes completos\\n");
            printf("Exemplo: mpirun -np 4 ./mpi_test\\n");
        }
    }
    
    if (rank == MASTER) {
        printf("\\n✓ Testes MPI concluídos!\\n");
    }
    
    MPI_Finalize();
    return EXIT_SUCCESS;
}
""",
                "README.md": """# Teste HPC - MPI


**Objetivo:** Validar computação distribuída com MPI

## Instalação MPI
```bash
# Ubuntu/Debian
sudo apt-get install mpich libmpich-dev

# ou OpenMPI
sudo apt-get install openmpi-bin libopenmpi-dev
```

## Compilação
```bash
mpicc -o mpi_test mpi_test.c
```

## Execução
```bash
# Com 4 processos
mpirun -np 4 ./mpi_test

# Com 8 processos
mpirun -np 8 ./mpi_test
```

## Conceitos testados
- Inicialização e finalização MPI
- Rank e size de processos
- Point-to-point communication (Send/Recv)
- Collective communication (Broadcast, Reduce)
- Sincronização (Barrier)

## Validação
- [ ] MPI instalado
- [ ] Compilação com mpicc
- [ ] Múltiplos processos executando
- [ ] Comunicação funcionando
- [ ] Operações coletivas corretas
""",
                "Makefile": """MPICC = mpicc
CFLAGS = -Wall -Wextra
TARGET = mpi_test

all: $(TARGET)

$(TARGET): mpi_test.c
\t$(MPICC) $(CFLAGS) -o $(TARGET) mpi_test.c

clean:
\trm -f $(TARGET)

run2: $(TARGET)
\tmpirun -np 2 ./$(TARGET)

run4: $(TARGET)
\tmpirun -np 4 ./$(TARGET)

run8: $(TARGET)
\tmpirun -np 8 ./$(TARGET)
"""
            }
        }
    }
}


def criar_estrutura_projetos(force=False):
    """
    Cria toda a estrutura de diretórios e arquivos dos projetos de teste
    organizados por linguagem de programação.
    
    Args:
        force: Se True, sobrescreve arquivos existentes. Se False, pula.
    """
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    
    total_projetos = sum(len(projs) for projs in PROJECTS.values())
    contador = 0
    skipped = 0
    
    print("=" * 70)
    print("GERAÇÃO DE PROJETOS DE TESTE PEDAGÓGICOS")
    print("Organização: POR LINGUAGEM DE PROGRAMAÇÃO")
    print(f"Modo: {'FORÇAR sobrescrita' if force else 'Preservar existentes'}")
    print("=" * 70)
    print()
    
    for linguagem, projetos in PROJECTS.items():
        print(f"📁 Linguagem: {linguagem}")
        
        for nome_projeto, config in projetos.items():
            contador += 1
            
            dir_projeto = BASE_DIR / linguagem / nome_projeto
            dir_projeto.mkdir(parents=True, exist_ok=True)
            
            for nome_arquivo, conteudo in config["files"].items():
                caminho_arquivo = dir_projeto / nome_arquivo
                caminho_arquivo.parent.mkdir(parents=True, exist_ok=True)
                
                if caminho_arquivo.exists() and not force:
                    skipped += 1
                    continue
                
                caminho_arquivo.write_text(conteudo, encoding='utf-8')
            
            num_arquivos = len(config['files'])
            status = "✓" if not (caminho_arquivo.exists() and not force and skipped > 0) else "⊘"
            print(f"  ✓ {nome_projeto:<30} ({num_arquivos} arquivos)")
    
    print()
    print("=" * 70)
    print(f"✓ CONCLUÍDO: {contador} projetos processados!")
    if skipped > 0:
        print(f"⊘ {skipped} arquivo(s) preservado(s) — use --force para sobrescrever")
    print(f"📂 Localização: {BASE_DIR.absolute()}")
    print("=" * 70)
    
    criar_indice_projetos()


def criar_indice_projetos():
    """
    Cria um arquivo README.md principal com índice dinâmico de todos os projetos
    organizados por linguagem, gerado a partir de PROJECTS (sem hardcoded).
    """
    readme_path = BASE_DIR / "README.md"
    
    lines = []
    lines.append("# Testes Pedagógicos - Laboratório de Desenvolvimento\n")
    lines.append("Este diretório contém projetos de teste para validação de ambientes de desenvolvimento")
    lines.append("**organizados por linguagem de programação**.\n")
    lines.append("## 📋 Índice de Projetos por Linguagem\n")

    for linguagem, projetos in PROJECTS.items():
        lines.append(f"\n### {linguagem}\n")
        for nome_projeto, config in projetos.items():
            caminho = f"{linguagem}/{nome_projeto}"
            descricao = config.get('descricao', '')
            lines.append(f"- **{nome_projeto}**: {descricao}")
            lines.append(f"  - [`{caminho}/`](./{caminho}/)")
        lines.append("")

    lines.append("\n## 🎯 Estrutura de Organização\n")
    lines.append("```\ntestes_pedagogicos_lab_por_linguagem/")
    for linguagem, projetos in PROJECTS.items():
        proj_names = list(proyectos.keys()) if False else list(projetos.keys())
        prefix = "└──" if linguagem == list(PROJECTS.keys())[-1] else "├──"
        lines.append(f"{prefix} {linguagem}/")
        connector = "│   " if linguagem != list(PROJECTS.keys())[-1] else "    "
        for i, nome in enumerate(proj_names):
            last = (i == len(proj_names) - 1)
            lines.append(f"{connector}{'└──' if last else '├──'} {nome}/")
    lines.append("```\n")

    lines.append("## 🚀 Como Usar\n")
    lines.append("1. Navegue até o diretório da linguagem desejada")
    lines.append("2. Entre no projeto específico")
    lines.append("3. Leia o README.md de cada projeto para instruções detalhadas")
    lines.append("4. Execute os testes conforme documentado\n")

    lines.append("## ✅ Checklist de Validação Geral\n")
    lines.append("Para cada ambiente, verifique:\n")
    lines.append("- [ ] Compilação/interpretação sem erros")
    lines.append("- [ ] Execução bem-sucedida")
    lines.append("- [ ] Saídas esperadas corretas")
    lines.append("- [ ] Ferramentas de build funcionando (make, cargo, npm, dotnet, etc.)")
    lines.append("- [ ] Dependências instaladas\n")

    lines.append("---")
    lines.append("**Gerado automaticamente pelo script de testes pedagógicos v4.0**")
    lines.append("**Organização: Por Linguagem de Programação**\n")

    conteudo = "\n".join(lines)
    readme_path.write_text(conteudo, encoding='utf-8')
    print(f"\n✓ Índice geral criado: {readme_path}")


if __name__ == "__main__":
    force = "--force" in sys.argv
    try:
        criar_estrutura_projetos(force=force)
    except Exception as e:
        print(f"\n❌ Erro ao gerar projetos: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
