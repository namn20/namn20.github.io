---
title: Chirpy 테마로 블로그 시작하기
author: pedro
date: 2026-01-05 10:10:00 +0900
categories: [Blogging, Tutorial]
tags: [writing]
render_with_liquid: false
---

## 1.Local Install

커스트마이징에 제한적이지 않은 [Github Fork](https://github.com/cotes2020/jekyll-theme-chirpy) 방식으로 작성함
- Device : MacOS Sequia - Version 15.7.3

1. Create a new fork 
- Repository name은 반드시 `[githubID].github.io` 형식
- 설정 후 create fork 

2. Branch 
- Branch(Default : master -> main) 변경
- Branch Protection rule 비활성화 

3. Git Clone
```bash
$ git clone https://github.com/jjikin/jjikin.github.io.git
```

4. jekyll 실행을 위한 모듈 설치
- 나의 로컬로 이동하여 bundle install
```bash
$ cd namn20.github.io
$ bundle install
```

5. ruby Install
- ruby를 설치했지만 version 문제로 다운그레이드 수행 후 환경 변수 설정
    > **경고:** 현재 루비 버전이 테마와 호환되지 않습니다. 3.1 버전 이상이 필요합니다. 4.0.0은 아직 호환이 안되는것 같음
    {: .prompt-warning }

6. npm Install
```bash
$ npm install && npm run build
```
7. 설치가 완료 후 로컬에서 jekyll 실행
- 실시간 반영을 위해 서버 실행 실행할때 `--furure` 옵션 추가
```bash
$ bundle exec jekyll serve --future
```

8. 웹 브라우저 127.0.0.1:4000 주소로 블로그 정상적으로 표시되는지 확인
- 블로그 내 여러 메뉴 및 기능들도 정상 동작하는지 확인



## 2. Github Deploy

실제 소스코드를 Github에 배포 

1. Github Setting 
- Settings -> Code and authomation -> Pages 
-- Build and deployment : `Github Actions`
     > **경고:** GitHub Actions로 소스를 변경하지 않거나, Configure를 완료하지 않고 배포할 경우 에러가 발생될수 있음
    {: .prompt-warning }



    1
    2
    3
    4
    5
    