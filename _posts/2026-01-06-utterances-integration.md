---
title: Jekyll Chirpy 테마에 Utterances 댓글 기능 추가하기
date: 2026-01-06 13:00:00 +0900
categories: [Blogging, Chirpy]
tags: [chirpy, utterances, comments, github]
---

## 개요

Jekyll 블로그를 운영할 때, 독자들과의 소통을 위한 댓글 기능은 필수적입니다. 여러 댓글 서비스가 있지만, Utterances는 개발자 블로그에 특히 잘 어울리는 훌륭한 대안입니다. GitHub 저장소의 이슈(Issue) 시스템을 기반으로 작동하여 광고가 없고, 가벼우며, 오픈소스라는 장점을 가집니다.

본 포스트에서는 Jekyll의 인기 테마인 **Chirpy**에 **Utterances**를 연동하여 댓글 기능을 손쉽게 추가하는 방법을 안내합니다.

---

## 1단계: 댓글 저장소(Repository) 생성

Utterances는 댓글을 GitHub 저장소의 이슈로 생성하고 관리합니다. 따라서 댓글을 저장할 전용 공개(Public) 저장소를 먼저 만들어야 합니다.

1.  GitHub에 로그인한 후, 새로운 저장소를 생성합니다. (e.g., `my-blog-comments`)
2.  반드시 **공개(Public)** 저장소로 설정해야 합니다. 비공개(Private) 저장소는 작동하지 않습니다.
3.  `README.md` 파일을 추가하여 빈 저장소가 아니도록 설정하는 것을 권장합니다.

![New Repo](https://docs.github.com/assets/cb-11133/images/help/repository/repo-create-new-repo-page.png)

---

## 2단계: Utterances GitHub App 설치

다음으로, 위에서 생성한 저장소에 Utterances 앱을 설치하고 권한을 부여해야 합니다.

1.  [Utterances 앱 설치 페이지](https://github.com/apps/utterances)로 이동하여 `Install` 버튼을 클릭합니다.
2.  설치 옵션에서 **"Only select repositories"**를 선택하고, 방금 생성한 댓글 전용 저장소(e.g., `my-blog-comments`)를 지정해 줍니다.
3.  `Install` 버튼을 눌러 설치를 완료합니다.

![Install Utterances](https://user-images.githubusercontent.com/1339022/42726391-73e42c86-872c-11e8-9034-247651239103.png)

---

## 3단계: `_config.yml` 설정하기

Chirpy 테마는 Utterances를 내장 지원하므로, 복잡한 코드 수정 없이 `_config.yml` 파일에 몇 줄의 설정만 추가하면 됩니다.

1.  블로그 프로젝트의 루트 디렉토리에 있는 `_config.yml` 파일을 엽니다.
2.  파일의 적당한 위치에 아래 `comments` 설정 블록을 추가합니다. (기존에 `disqus` 설정이 있다면 그 근처에 추가하는 것이 좋습니다.)

    ```yaml
    # _config.yml

    comments:
      provider: "utterances" # 댓글 기능으로 Utterances를 사용하도록 지정
      utterances:
        repo: "your-github-username/your-repo-name" # 1단계에서 생성한 댓글 저장소 (e.g., namn20/my-blog-comments)
        issue_term: "pathname" # 포스트와 이슈를 매핑하는 방식
    ```

3.  **설정값 설명:**
    - `provider`: Chirpy 테마에게 `utterances`를 댓글 기능으로 사용하겠다고 알리는 역할입니다.
    - `repo`: **가장 중요한 부분입니다.** `"your-github-username/your-repo-name"` 부분을 본인의 GitHub 사용자명과 1단계에서 생성한 댓글 저장소 이름으로 반드시 변경해야 합니다.
    - `issue_term`: 블로그 포스트와 GitHub 이슈를 어떤 기준으로 연결할지 정하는 옵션입니다. `pathname`을 사용하면 블로그 포스트의 URL 경로를 기준으로 이슈가 생성되므로, 가장 일반적으로 추천되는 방식입니다.

---

## 4단계: 확인하기

모든 설정이 완료되었습니다. 이제 블로그에 접속하여 댓글 창이 정상적으로 표시되는지 확인합니다.

- **로컬에서 확인:** 터미널에서 `bundle exec jekyll s` 명령을 실행하여 로컬 서버를 구동한 후, 아무 포스트에나 접속하여 맨 아래에 Utterances 댓글 창이 보이는지 확인합니다.
- **GitHub Pages 배포:** `_config.yml` 변경 사항을 commit하고 GitHub에 push합니다. 잠시 후 사이트가 다시 빌드되면 포스트에서 댓글 기능을 확인할 수 있습니다.

성공적으로 연동되었다면, 아래와 같이 포스트 하단에 GitHub 계정으로 로그인하고 댓글을 작성할 수 있는 창이 나타날 것입니다.

![Utterances Widget](https://user-images.githubusercontent.com/1339022/42726401-79dc2004-872c-11e8-9 utterances-comment-box.png)

## 결론

이제 당신의 Jekyll 블로그에도 멋진 댓글 기능이 추가되었습니다. Utterances를 통해 독자들과 더 활발하게 소통하고 블로그를 풍성하게 만들어 보세요. 설정 과정에서 문제가 발생하면 `_config.yml`의 `repo` 설정이 정확한지 다시 한번 확인하는 것이 좋습니다.
