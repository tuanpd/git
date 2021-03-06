#!/bin/sh

test_description='auto squash'

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success setup '
	echo 0 >file0 &&
	git add . &&
	test_tick &&
	git commit -m "initial commit" &&
	echo 0 >file1 &&
	echo 2 >file2 &&
	git add . &&
	test_tick &&
	git commit -m "first commit" &&
	git tag first-commit &&
	echo 3 >file3 &&
	git add . &&
	test_tick &&
	git commit -m "second commit" &&
	git tag base
'

test_auto_fixup () {
	git reset --hard base &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "fixup! first" &&

	git tag $1 &&
	test_tick &&
	git rebase $2 -i HEAD^^^ &&
	git log --oneline >actual &&
	test_line_count = 3 actual &&
	git diff --exit-code $1 &&
	test 1 = "$(git cat-file blob HEAD^:file1)" &&
	test 1 = $(git cat-file commit HEAD^ | grep first | wc -l)
}

test_expect_success 'auto fixup (option)' '
	test_auto_fixup final-fixup-option --autosquash
'

test_expect_success 'auto fixup (config)' '
	git config rebase.autosquash true &&
	test_auto_fixup final-fixup-config-true &&
	test_must_fail test_auto_fixup fixup-config-true-no --no-autosquash &&
	git config rebase.autosquash false &&
	test_must_fail test_auto_fixup final-fixup-config-false
'

test_auto_squash () {
	git reset --hard base &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "squash! first" &&

	git tag $1 &&
	test_tick &&
	git rebase $2 -i HEAD^^^ &&
	git log --oneline >actual &&
	test_line_count = 3 actual &&
	git diff --exit-code $1 &&
	test 1 = "$(git cat-file blob HEAD^:file1)" &&
	test 2 = $(git cat-file commit HEAD^ | grep first | wc -l)
}

test_expect_success 'auto squash (option)' '
	test_auto_squash final-squash --autosquash
'

test_expect_success 'auto squash (config)' '
	git config rebase.autosquash true &&
	test_auto_squash final-squash-config-true &&
	test_must_fail test_auto_squash squash-config-true-no --no-autosquash &&
	git config rebase.autosquash false &&
	test_must_fail test_auto_squash final-squash-config-false
'

test_expect_success 'misspelled auto squash' '
	git reset --hard base &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "squash! forst" &&
	git tag final-missquash &&
	test_tick &&
	git rebase --autosquash -i HEAD^^^ &&
	git log --oneline >actual &&
	test_line_count = 4 actual &&
	git diff --exit-code final-missquash &&
	test 0 = $(git rev-list final-missquash...HEAD | wc -l)
'

test_expect_success 'auto squash that matches 2 commits' '
	git reset --hard base &&
	echo 4 >file4 &&
	git add file4 &&
	test_tick &&
	git commit -m "first new commit" &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "squash! first" &&
	git tag final-multisquash &&
	test_tick &&
	git rebase --autosquash -i HEAD~4 &&
	git log --oneline >actual &&
	test_line_count = 4 actual &&
	git diff --exit-code final-multisquash &&
	test 1 = "$(git cat-file blob HEAD^^:file1)" &&
	test 2 = $(git cat-file commit HEAD^^ | grep first | wc -l) &&
	test 1 = $(git cat-file commit HEAD | grep first | wc -l)
'

test_expect_success 'auto squash that matches a commit after the squash' '
	git reset --hard base &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "squash! third" &&
	echo 4 >file4 &&
	git add file4 &&
	test_tick &&
	git commit -m "third commit" &&
	git tag final-presquash &&
	test_tick &&
	git rebase --autosquash -i HEAD~4 &&
	git log --oneline >actual &&
	test_line_count = 5 actual &&
	git diff --exit-code final-presquash &&
	test 0 = "$(git cat-file blob HEAD^^:file1)" &&
	test 1 = "$(git cat-file blob HEAD^:file1)" &&
	test 1 = $(git cat-file commit HEAD | grep third | wc -l) &&
	test 1 = $(git cat-file commit HEAD^ | grep third | wc -l)
'
test_expect_success 'auto squash that matches a sha1' '
	git reset --hard base &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "squash! $(git rev-parse --short HEAD^)" &&
	git tag final-shasquash &&
	test_tick &&
	git rebase --autosquash -i HEAD^^^ &&
	git log --oneline >actual &&
	test_line_count = 3 actual &&
	git diff --exit-code final-shasquash &&
	test 1 = "$(git cat-file blob HEAD^:file1)" &&
	test 1 = $(git cat-file commit HEAD^ | grep squash | wc -l)
'

test_expect_success 'auto squash that matches longer sha1' '
	git reset --hard base &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "squash! $(git rev-parse --short=11 HEAD^)" &&
	git tag final-longshasquash &&
	test_tick &&
	git rebase --autosquash -i HEAD^^^ &&
	git log --oneline >actual &&
	test_line_count = 3 actual &&
	git diff --exit-code final-longshasquash &&
	test 1 = "$(git cat-file blob HEAD^:file1)" &&
	test 1 = $(git cat-file commit HEAD^ | grep squash | wc -l)
'

test_auto_commit_flags () {
	git reset --hard base &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit --$1 first-commit &&
	git tag final-commit-$1 &&
	test_tick &&
	git rebase --autosquash -i HEAD^^^ &&
	git log --oneline >actual &&
	test_line_count = 3 actual &&
	git diff --exit-code final-commit-$1 &&
	test 1 = "$(git cat-file blob HEAD^:file1)" &&
	test $2 = $(git cat-file commit HEAD^ | grep first | wc -l)
}

test_expect_success 'use commit --fixup' '
	test_auto_commit_flags fixup 1
'

test_expect_success 'use commit --squash' '
	test_auto_commit_flags squash 2
'

test_auto_fixup_fixup () {
	git reset --hard base &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "$1! first" &&
	echo 2 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "$1! $2! first" &&
	git tag "final-$1-$2" &&
	test_tick &&
	(
		set_cat_todo_editor &&
		test_must_fail git rebase --autosquash -i HEAD^^^^ >actual &&
		cat >expected <<-EOF &&
		pick $(git rev-parse --short HEAD^^^) first commit
		$1 $(git rev-parse --short HEAD^) $1! first
		$1 $(git rev-parse --short HEAD) $1! $2! first
		pick $(git rev-parse --short HEAD^^) second commit
		EOF
		test_cmp expected actual
	) &&
	git rebase --autosquash -i HEAD^^^^ &&
	git log --oneline >actual &&
	test_line_count = 3 actual
	git diff --exit-code "final-$1-$2" &&
	test 2 = "$(git cat-file blob HEAD^:file1)" &&
	if test "$1" = "fixup"
	then
		test 1 = $(git cat-file commit HEAD^ | grep first | wc -l)
	elif test "$1" = "squash"
	then
		test 3 = $(git cat-file commit HEAD^ | grep first | wc -l)
	else
		false
	fi
}

test_expect_success C_LOCALE_OUTPUT 'fixup! fixup!' '
	test_auto_fixup_fixup fixup fixup
'

test_expect_success C_LOCALE_OUTPUT 'fixup! squash!' '
	test_auto_fixup_fixup fixup squash
'

test_expect_success C_LOCALE_OUTPUT 'squash! squash!' '
	test_auto_fixup_fixup squash squash
'

test_expect_success C_LOCALE_OUTPUT 'squash! fixup!' '
	test_auto_fixup_fixup squash fixup
'

test_expect_success C_LOCALE_OUTPUT 'autosquash with custom inst format' '
	git reset --hard base &&
	git config --add rebase.instructionFormat "[%an @ %ar] %s"  &&
	echo 2 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "squash! $(git rev-parse --short HEAD^)" &&
	echo 1 >file1 &&
	git add -u &&
	test_tick &&
	git commit -m "squash! $(git log -n 1 --format=%s HEAD~2)" &&
	git tag final-squash-instFmt &&
	test_tick &&
	git rebase --autosquash -i HEAD~4 &&
	git log --oneline >actual &&
	test_line_count = 3 actual &&
	git diff --exit-code final-squash-instFmt &&
	test 1 = "$(git cat-file blob HEAD^:file1)" &&
	test 2 = $(git cat-file commit HEAD^ | grep squash | wc -l)
'

test_expect_success 'autosquash with empty custom instructionFormat' '
	git reset --hard base &&
	test_commit empty-instructionFormat-test &&
	(
		set_cat_todo_editor &&
		test_must_fail git -c rebase.instructionFormat= \
			rebase --autosquash  --force -i HEAD^ >actual &&
		git log -1 --format="pick %h %s" >expect &&
		test_cmp expect actual
	)
'

set_backup_editor () {
	write_script backup-editor.sh <<-\EOF
	cp "$1" .git/backup-"$(basename "$1")"
	EOF
	test_set_editor "$PWD/backup-editor.sh"
}

test_expect_success 'autosquash with multiple empty patches' '
	test_tick &&
	git commit --allow-empty -m "empty" &&
	test_tick &&
	git commit --allow-empty -m "empty2" &&
	test_tick &&
	>fixup &&
	git add fixup &&
	git commit --fixup HEAD^^ &&
	(
		set_backup_editor &&
		GIT_USE_REBASE_HELPER=false \
		git rebase -i --force-rebase --autosquash HEAD~4 &&
		grep empty2 .git/backup-git-rebase-todo
	)
'

test_expect_success 'extra spaces after fixup!' '
	base=$(git rev-parse HEAD) &&
	test_commit to-fixup &&
	git commit --allow-empty -m "fixup!  to-fixup" &&
	git rebase -i --autosquash --keep-empty HEAD~2 &&
	parent=$(git rev-parse HEAD^) &&
	test $base = $parent
'

test_expect_success 'wrapped original subject' '
	if test -d .git/rebase-merge; then git rebase --abort; fi &&
	base=$(git rev-parse HEAD) &&
	echo "wrapped subject" >wrapped &&
	git add wrapped &&
	test_tick &&
	git commit --allow-empty -m "$(printf "To\nfixup")" &&
	test_tick &&
	git commit --allow-empty -m "fixup! To fixup" &&
	git rebase -i --autosquash --keep-empty HEAD~2 &&
	parent=$(git rev-parse HEAD^) &&
	test $base = $parent
'

test_expect_success 'abort last squash' '
	test_when_finished "test_might_fail git rebase --abort" &&
	test_when_finished "git checkout master" &&

	git checkout -b some-squashes &&
	git commit --allow-empty -m first &&
	git commit --allow-empty --squash HEAD &&
	git commit --allow-empty -m second &&
	git commit --allow-empty --squash HEAD &&

	test_must_fail git -c core.editor="grep -q ^pick" \
		rebase -ki --autosquash HEAD~4 &&
	: do not finish the squash, but resolve it manually &&
	git commit --allow-empty --amend -m edited-first &&
	git rebase --skip &&
	git show >actual &&
	! grep first actual
'

test_done
