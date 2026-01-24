# Github commit 메세지 형식 통일

(action): (detail)


**action 목록**

- add: 새로운 폴더, 파일, 분기(Branch) 추가
- modify: 기존의 파일에서 수정한 사항 존재
- delete: 기존의 파일에서 지운 사항 존재
- alter: 기존의 코드를 지우고 대체한 부분 존재
- update: 새로운 기능을 추가하거나 새로운 분기를 생성
- rollback: 이전의 코드로 돌아감

  ex)

- add: 가속도 센서 예제 파일 commit (실제 첫번째 commit 메세지)
- modify: 변수명 통일을 위한 aaa.v 파일의 변수명 변경
- add: bb.v 파일 commit // modify: ccc.v 파일의 로직 변경 (여러개의 action 한번에 작성 가능)
