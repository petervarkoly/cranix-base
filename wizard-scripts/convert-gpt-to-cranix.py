#!/usr/bin/python3

import sys
import json

teachingSubject = { "name":sys.argv[3] }
challenge = {
    "description":sys.argv[2],
    "teachingSubject": teachingSubject,
    "questions":[]
}

if len(sys.argv) > 4:
    challenge["subjectAreaList"] = sys.argv[4]
with open(sys.argv[1]) as f:
    questions = json.load(f)
    for question in questions["questions"]:
        count = 0
        tmp_qeust = {
            "value":1,
            "answerType":"One",
            "question":"<p>" + question["question"] + "</p>",
            "crxQuestionAnswers":[]
        }
        for answer in question["options"]:
            tmp_qeust["crxQuestionAnswers"].append(
                {
                    "answer": "<p>" + answer + "</p>",
                    "correct" : question["answer"] == count
                }
            )
            count = count + 1
        challenge["questions"].append(tmp_qeust)
with open("/tmp/111","w") as f:
    json.dump(challenge ,f ,ensure_ascii=False)

